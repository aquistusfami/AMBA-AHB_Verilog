// =============================================================================
// Module : ahb_slave.v
// Description : AHB-Lite Slave với Dummy RAM (giả lập bộ nhớ)
//               Tuân theo AMBA AHB Specification Rev 2.0 (ARM IHI0011A)
//
// Tính năng:
//   - Bộ nhớ giả lập 1KB (256 x 32-bit words)
//   - Hỗ trợ Byte / Halfword / Word access
//   - Trả về HRESP = OKAY cho địa chỉ hợp lệ
//   - Trả về HRESP = ERROR (2-cycle) cho địa chỉ ngoài vùng (Section 3.9.3)
//   - Có thể cấu hình wait state qua parameter WAIT_STATES
//   - HSEL-aware: chỉ phản hồi khi được chọn
// =============================================================================

module ahb_slave #(
    parameter MEM_DEPTH  = 256,      // Số words 32-bit (= 1KB)
    parameter BASE_ADDR  = 32'h0000_0000,
    parameter WAIT_STATES = 0        // Số wait state (0 = zero-wait)
)(
    // Clock & Reset
    input  wire        HCLK,
    input  wire        HRESETn,

    // AHB Slave Inputs
    input  wire        HSEL,         // Slave select từ decoder
    input  wire [31:0] HADDR,        // Address
    input  wire        HWRITE,       // 1=Write, 0=Read
    input  wire [2:0]  HSIZE,        // Transfer size
    input  wire [2:0]  HBURST,       // Burst type (slave cần để xử lý wrap)
    input  wire [1:0]  HTRANS,       // Transfer type
    input  wire [3:0]  HPROT,        // Protection (slave có thể ignore)
    input  wire [31:0] HWDATA,       // Write data (valid 1 cycle sau address)
    input  wire        HREADY_IN,    // HREADY từ bus (slave dùng để sample addr)

    // AHB Slave Outputs
    output reg  [31:0] HRDATA,       // Read data
    output reg         HREADY_OUT,   // 1=Ready, 0=Insert wait state
    output reg  [1:0]  HRESP         // Transfer response
);

    // -------------------------------------------------------------------------
    // HTRANS / HRESP Constants
    // -------------------------------------------------------------------------
    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_BUSY   = 2'b01;
    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    localparam HRESP_OKAY    = 2'b00;
    localparam HRESP_ERROR   = 2'b01;

    // -------------------------------------------------------------------------
    // Dummy RAM
    // -------------------------------------------------------------------------
    reg [31:0] mem [0:MEM_DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;
    end

    // -------------------------------------------------------------------------
    // Internal Registers
    // -------------------------------------------------------------------------
    // AHB là pipelined: address phase T1, data phase T2
    // Slave phải chốt (latch) địa chỉ và control ở cuối address phase
    reg [31:0] addr_lat;         // Địa chỉ chốt
    reg        write_lat;        // Hướng transfer chốt
    reg [2:0]  size_lat;         // Kích thước chốt
    reg        sel_lat;          // HSEL chốt
    reg        trans_valid_lat;  // Transfer có hiệu lực không

    reg [3:0]  wait_cnt;         // Bộ đếm wait state
    reg        err_phase2;       // Cờ second cycle của ERROR response

    // -------------------------------------------------------------------------
    // Address decode: kiểm tra địa chỉ có hợp lệ không
    // -------------------------------------------------------------------------
    wire [31:0] addr_offset = addr_lat - BASE_ADDR;
    wire [7:0]  word_index  = addr_offset[9:2];   // Word index (1KB = 10-bit space)
    wire        addr_valid  = (addr_lat >= BASE_ADDR) &&
                              (addr_lat < (BASE_ADDR + MEM_DEPTH * 4));

    // -------------------------------------------------------------------------
    // Sequential: Chốt address phase
    // Theo spec: "A slave must only sample the address and control signals
    // and HSELx when HREADY is HIGH" (Section 3.8)
    // -------------------------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_lat        <= 32'h0;
            write_lat       <= 1'b0;
            size_lat        <= 3'b010;
            sel_lat         <= 1'b0;
            trans_valid_lat <= 1'b0;
        end else if (HREADY_IN) begin
            // Chỉ sample khi HREADY HIGH (transfer hiện tại đang kết thúc)
            addr_lat        <= HADDR;
            write_lat       <= HWRITE;
            size_lat        <= HSIZE;
            sel_lat         <= HSEL;
            // Transfer hợp lệ: HSEL cao VÀ HTRANS là NONSEQ hoặc SEQ
            trans_valid_lat <= HSEL && (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ);
        end
    end

    // -------------------------------------------------------------------------
    // Sequential: Response Logic + RAM Read/Write
    // -------------------------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HRDATA      <= 32'h0;
            HREADY_OUT  <= 1'b1;
            HRESP       <= HRESP_OKAY;
            wait_cnt    <= 4'h0;
            err_phase2  <= 1'b0;
        end else begin

            // ------------------------------------------------------------------
            // Xử lý ERROR response 2-cycle (Section 3.9.3)
            // Cycle 1: HREADY=0, HRESP=ERROR
            // Cycle 2: HREADY=1, HRESP=ERROR
            // ------------------------------------------------------------------
            if (err_phase2) begin
                HREADY_OUT <= 1'b1;
                HRESP      <= HRESP_OKAY; // Trở về OKAY sau khi báo xong
                err_phase2 <= 1'b0;
                $display("[AHB_SLAVE] ERROR response cycle-2 @ addr=0x%08h, t=%0t", addr_lat, $time);
            end

            else if (trans_valid_lat) begin
                // Địa chỉ ngoài phạm vi → ERROR 2-cycle
                if (!addr_valid) begin
                    HREADY_OUT <= 1'b0;     // Cycle 1: extend transfer
                    HRESP      <= HRESP_ERROR;
                    err_phase2 <= 1'b1;
                    $display("[AHB_SLAVE] Invalid addr=0x%08h, issuing ERROR, t=%0t", addr_lat, $time);
                end

                // Wait state chưa đủ
                else if (wait_cnt < WAIT_STATES) begin
                    HREADY_OUT <= 1'b0;
                    HRESP      <= HRESP_OKAY;
                    wait_cnt   <= wait_cnt + 1'b1;
                end

                // Transfer thực sự xử lý
                else begin
                    wait_cnt   <= 4'h0;
                    HREADY_OUT <= 1'b1;
                    HRESP      <= HRESP_OKAY;

                    if (write_lat) begin
                        // ------------------------------------------------
                        // WRITE: ghi vào RAM theo kích thước (HSIZE)
                        // ------------------------------------------------
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
                            3'b001: begin // Halfword
                                if (!addr_lat[0]) begin // Aligned check
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
                            default: mem[word_index] <= HWDATA; // Xử lý rộng hơn nếu cần
                        endcase
                        HRDATA <= 32'h0; // Không dùng trong write

                    end else begin
                        // ------------------------------------------------
                        // READ: đọc từ RAM theo kích thước
                        // ------------------------------------------------
                        case (size_lat)
                            3'b000: begin // Byte — trả về trên đúng byte lane
                                case (addr_lat[1:0])
                                    2'b00: HRDATA <= {24'h0, mem[word_index][7:0]};
                                    2'b01: HRDATA <= {16'h0, mem[word_index][15:8],  8'h0};
                                    2'b10: HRDATA <= {8'h0,  mem[word_index][23:16], 16'h0};
                                    2'b11: HRDATA <= {       mem[word_index][31:24], 24'h0};
                                endcase
                                $display("[AHB_SLAVE] READ  Byte  @ 0x%08h = 0x%02h, t=%0t",
                                         addr_lat, mem[word_index][7:0], $time);
                            end
                            3'b001: begin // Halfword
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
                // Không có transfer hợp lệ (IDLE/BUSY) hoặc không được chọn
                // → phản hồi ngay OKAY, không cần wait
                HREADY_OUT <= 1'b1;
                HRESP      <= HRESP_OKAY;
                HRDATA     <= 32'h0;
            end
        end
    end

endmodule
