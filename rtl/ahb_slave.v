// Slave bộ nhớ đơn giản cho AHB.
// Hỗ trợ byte, nửa word, word và ERROR hai chu kỳ.

module ahb_slave #(
    parameter MEM_DEPTH  = 256,      // Số word 32 bit
    parameter BASE_ADDR  = 32'h0000_0000,
    parameter WAIT_STATES = 0        // Số chu kỳ chờ
)(
    // Xung nhịp và reset.
    input  wire        HCLK,
    input  wire        HRESETn,

    // Tín hiệu vào từ bus.
    input  wire        HSEL,         // Chọn slave
    input  wire [31:0] HADDR,        // Địa chỉ
    input  wire        HWRITE,       // 1 ghi, 0 đọc
    input  wire [2:0]  HSIZE,        // Kích thước
    input  wire [2:0]  HBURST,       // Kiểu burst
    input  wire [1:0]  HTRANS,       // Kiểu truyền
    input  wire [3:0]  HPROT,        // Thuộc tính bảo vệ
    input  wire [31:0] HWDATA,       // Dữ liệu ghi
    input  wire        HREADY_IN,    // Bus sẵn sàng
    input  wire        stall_req,     // Ép chu kỳ chờ

    // Tín hiệu trả về bus.
    output reg  [31:0] HRDATA,       // Dữ liệu đọc
    output reg         HREADY_OUT,   // Slave sẵn sàng
    output reg  [1:0]  HRESP         // Phản hồi
);

    // Hằng số giao thức.
    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_BUSY   = 2'b01;
    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    localparam HRESP_OKAY    = 2'b00;
    localparam HRESP_ERROR   = 2'b01;

    // RAM nội bộ.
    reg [31:0] mem [0:MEM_DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;
    end

    // Thanh ghi pha địa chỉ.
    reg [31:0] addr_lat;         // Địa chỉ
    reg        write_lat;        // Hướng truyền
    reg [2:0]  size_lat;         // Kích thước
    reg        sel_lat;          // Chọn slave
    reg        trans_valid_lat;  // Truyền hợp lệ

    reg [3:0]  wait_cnt;         // Đếm chu kỳ chờ
    reg        err_phase2;       // Pha hai của ERROR
    reg        err_done;         // Giữ ERROR thêm một chu kỳ

    // Kiểm tra vùng địa chỉ.
    wire [31:0] addr_offset = addr_lat - BASE_ADDR;
    wire [7:0]  word_index  = addr_offset[9:2];   // Chỉ số word
    wire        addr_valid  = (addr_lat >= BASE_ADDR) &&
                              (addr_lat < (BASE_ADDR + MEM_DEPTH * 4));

    // Chốt pha địa chỉ khi HREADY cao.
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_lat        <= 32'h0;
            write_lat       <= 1'b0;
            size_lat        <= 3'b010;
            sel_lat         <= 1'b0;
            trans_valid_lat <= 1'b0;
        end else if (HREADY_IN) begin
            // Chỉ lấy mẫu khi bus sẵn sàng.
            addr_lat        <= HADDR;
            write_lat       <= HWRITE;
            size_lat        <= HSIZE;
            sel_lat         <= HSEL;
            // Truyền hợp lệ là NONSEQ hoặc SEQ.
            trans_valid_lat <= HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ);
        end
    end

    // Xử lý phản hồi và truy cập RAM.
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HRDATA      <= 32'h0;
            HREADY_OUT  <= 1'b1;
            HRESP       <= HRESP_OKAY;
            wait_cnt    <= 4'h0;
            err_phase2  <= 1'b0;
            err_done    <= 1'b0;
        end else begin

            // ERROR cần hai chu kỳ theo AHB.
            if (err_phase2) begin
                HREADY_OUT <= 1'b1;
                HRESP      <= HRESP_ERROR;
                err_phase2 <= 1'b0;
                err_done   <= 1'b1;
                $display("[AHB_SLAVE] ERROR response cycle-2 @ addr=0x%08h, t=%0t", addr_lat, $time);
            end

            else if (err_done) begin
                HREADY_OUT <= 1'b1;
                HRESP      <= HRESP_ERROR;
                err_done   <= 1'b0;
            end

            else if (trans_valid_lat) begin
                // Địa chỉ ngoài vùng trả ERROR.
                if (!addr_valid) begin
                    HREADY_OUT <= 1'b0;     // Kéo dài lần truyền
                    HRESP      <= HRESP_ERROR;
                    err_phase2 <= 1'b1;
                    $display("[AHB_SLAVE] Invalid addr=0x%08h, issuing ERROR, t=%0t", addr_lat, $time);
                end

                // Chèn chu kỳ chờ.
                else if (stall_req || (wait_cnt < WAIT_STATES)) begin
                    HREADY_OUT <= 1'b0;
                    HRESP      <= HRESP_OKAY;
                    if (!stall_req)
                        wait_cnt <= wait_cnt + 1'b1;
                end

                // Thực hiện truyền.
                else begin
                    wait_cnt   <= 4'h0;
                    HREADY_OUT <= 1'b1;
                    HRESP      <= HRESP_OKAY;

                    if (write_lat) begin
                        // Ghi RAM theo HSIZE.
                        case (size_lat)
                            3'b000: begin // Byte
                                case (addr_lat[1:0])
                                    2'b00: mem[word_index][7:0]   <= HWDATA[7:0];
                                    2'b01: mem[word_index][15:8]  <= HWDATA[15:8];
                                    2'b10: mem[word_index][23:16] <= HWDATA[23:16];
                                    2'b11: mem[word_index][31:24] <= HWDATA[31:24];
                                endcase
                                $display("[AHB_SLAVE] WRITE Byte  @ 0x%08h = 0x%02h, t=%0t",
                                         addr_lat, HWDATA[7:0], $time);
                            end
                            3'b001: begin // Nửa word
                                if (!addr_lat[0]) begin // Kiểm tra căn chỉnh
                                    if (addr_lat[1])
                                        mem[word_index][31:16] <= HWDATA[31:16];
                                    else
                                        mem[word_index][15:0]  <= HWDATA[15:0];
                                end
                                $display("[AHB_SLAVE] WRITE HWord @ 0x%08h = 0x%04h, t=%0t",
                                         addr_lat, HWDATA[15:0], $time);
                            end
                            3'b010: begin // Word
                                mem[word_index] <= HWDATA;
                                $display("[AHB_SLAVE] WRITE Word  @ 0x%08h = 0x%08h, t=%0t",
                                         addr_lat, HWDATA, $time);
                            end
                            default: mem[word_index] <= HWDATA; // Mặc định ghi word
                        endcase
                        HRDATA <= 32'h0; // Không dùng khi ghi

                    end else begin
                        // Đọc RAM theo HSIZE.
                        case (size_lat)
                            3'b000: begin // Byte
                                case (addr_lat[1:0])
                                    2'b00: HRDATA <= {24'h0, mem[word_index][7:0]};
                                    2'b01: HRDATA <= {16'h0, mem[word_index][15:8],  8'h0};
                                    2'b10: HRDATA <= {8'h0,  mem[word_index][23:16], 16'h0};
                                    2'b11: HRDATA <= {       mem[word_index][31:24], 24'h0};
                                endcase
                                $display("[AHB_SLAVE] READ  Byte  @ 0x%08h = 0x%02h, t=%0t",
                                         addr_lat, mem[word_index][7:0], $time);
                            end
                            3'b001: begin // Nửa word
                                if (addr_lat[1])
                                    HRDATA <= {mem[word_index][31:16], 16'h0};
                                else
                                    HRDATA <= {16'h0, mem[word_index][15:0]};
                                $display("[AHB_SLAVE] READ  HWord @ 0x%08h = 0x%04h, t=%0t",
                                         addr_lat, mem[word_index][15:0], $time);
                            end
                            3'b010: begin // Word
                                HRDATA <= mem[word_index];
                                $display("[AHB_SLAVE] READ  Word  @ 0x%08h = 0x%08h, t=%0t",
                                         addr_lat, mem[word_index], $time);
                            end
                            default: HRDATA <= mem[word_index];
                        endcase
                    end
                end
            end else begin
                // Không được chọn thì trả OKAY.
                HREADY_OUT <= 1'b1;
                HRESP      <= HRESP_OKAY;
                HRDATA     <= 32'h0;
            end
        end
    end

endmodule

module ahb_default_slave (
    input  wire       HCLK,
    input  wire       HRESETn,
    input  wire       HSEL,
    input  wire [1:0] HTRANS,
    input  wire       HREADY_IN,
    output reg        HREADY_OUT,
    output reg  [1:0] HRESP,
    output wire [31:0] HRDATA
);

    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;
    localparam HRESP_OKAY    = 2'b00;
    localparam HRESP_ERROR   = 2'b01;

    reg trans_valid_lat;
    reg err_phase2;
    reg err_done;

    assign HRDATA = 32'h0;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            trans_valid_lat <= 1'b0;
        end else if (HREADY_IN) begin
            trans_valid_lat <= HSEL && ((HTRANS == HTRANS_NONSEQ) || (HTRANS == HTRANS_SEQ));
        end
    end

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HREADY_OUT <= 1'b1;
            HRESP      <= HRESP_OKAY;
            err_phase2 <= 1'b0;
            err_done   <= 1'b0;
        end else if (err_phase2) begin
            HREADY_OUT <= 1'b1;
            HRESP      <= HRESP_ERROR;
            err_phase2 <= 1'b0;
            err_done   <= 1'b1;
        end else if (err_done) begin
            HREADY_OUT <= 1'b1;
            HRESP      <= HRESP_ERROR;
            err_done   <= 1'b0;
        end else if (trans_valid_lat) begin
            HREADY_OUT <= 1'b0;
            HRESP      <= HRESP_ERROR;
            err_phase2 <= 1'b1;
        end else begin
            HREADY_OUT <= 1'b1;
            HRESP      <= HRESP_OKAY;
        end
    end

endmodule
