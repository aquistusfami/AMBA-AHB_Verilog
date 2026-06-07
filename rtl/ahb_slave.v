`timescale 1ns / 1ps
`include "ahb_defines.v"

// Bộ tớ bộ nhớ đơn giản cho AHB.
// Hỗ trợ byte, nửa từ, từ và phản hồi ERROR hai chu kỳ.

module ahb_slave #(
    parameter MEM_DEPTH  = 256,      // Số từ 32 bit
    parameter BASE_ADDR  = 32'h0000_0000,
    parameter WAIT_STATES = 0,       // Số chu kỳ chờ
    parameter MAX_STALL_CYCLES = 16  // Giới hạn chu kỳ chờ trước khi trả ERROR
)(
    // Xung nhịp và tín hiệu đặt lại.
    input  wire        HCLK,
    input  wire        HRESETn,

    // Tín hiệu vào từ bus.
    input  wire        HSEL,         // Chọn bộ tớ
    input  wire [31:0] HADDR,        // Địa chỉ
    input  wire        HWRITE,       // 1 ghi, 0 đọc
    input  wire [2:0]  HSIZE,        // Kích thước
    input  wire [2:0]  HBURST,       // Kiểu chuỗi truyền
    input  wire [1:0]  HTRANS,       // Kiểu truyền
    input  wire [3:0]  HPROT,        // Thuộc tính bảo vệ
    input  wire [31:0] HWDATA,       // Dữ liệu ghi
    input  wire        HREADY_IN,    // Bus sẵn sàng
    input  wire        stall_req,     // Ép chu kỳ chờ

    // Tín hiệu trả về bus.
    output reg  [31:0] HRDATA,       // Dữ liệu đọc
    output reg         HREADY_OUT,   // Bộ tớ sẵn sàng
    output reg  [1:0]  HRESP         // Phản hồi
);

    localparam MEM_INDEX_W   = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH);

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
    reg        sel_lat;          // Chọn bộ tớ
    reg        trans_valid_lat;  // Truyền hợp lệ

    reg [3:0]  wait_cnt;         // Đếm chu kỳ chờ
    reg        err_phase2;       // Pha hai của ERROR
    reg        hready_out_reg;
    reg [1:0]  hresp_reg;
    reg [31:0] read_data;
    reg [31:0] write_data_lane;

    // Kiểm tra vùng địa chỉ.
    wire [31:0] addr_offset = addr_lat - BASE_ADDR;
    wire [MEM_INDEX_W-1:0] word_index = addr_offset[MEM_INDEX_W+1:2]; // Chỉ số từ
    wire        addr_valid  = (addr_lat >= BASE_ADDR) &&
                              (addr_lat < (BASE_ADDR + MEM_DEPTH * 4));
    wire        size_valid  = (size_lat <= `AHB_HSIZE_MAX);
    wire        addr_aligned = (size_lat == `AHB_HSIZE_BYTE) ||
                               ((size_lat == `AHB_HSIZE_HALF) && !addr_lat[0]) ||
                               ((size_lat == `AHB_HSIZE_WORD) && (addr_lat[1:0] == 2'b00));
    wire        transfer_error = !addr_valid || !size_valid || !addr_aligned;

    // Chốt pha địa chỉ khi HREADY cao.
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_lat        <= 32'h0;
            write_lat       <= 1'b0;
            size_lat        <= `AHB_HSIZE_WORD;
            sel_lat         <= 1'b0;
            trans_valid_lat <= 1'b0;
        end else if (HREADY_IN) begin
            // Chỉ lấy mẫu khi bus sẵn sàng.
            addr_lat        <= HADDR;
            write_lat       <= HWRITE;
            size_lat        <= HSIZE;
            sel_lat         <= HSEL;
            // Tập con hiện tại chỉ hỗ trợ giao dịch NONSEQ đơn.
            trans_valid_lat <= HSEL && (HTRANS == `AHB_HTRANS_NONSEQ);
        end
    end

    always @(*) begin
        if (trans_valid_lat && addr_valid && !write_lat) begin
            case (size_lat)
                `AHB_HSIZE_BYTE: begin
                    case (addr_lat[1:0])
                        2'b00: read_data = {24'h0, mem[word_index][7:0]};
                        2'b01: read_data = {16'h0, mem[word_index][15:8], 8'h0};
                        2'b10: read_data = {8'h0, mem[word_index][23:16], 16'h0};
                        default: read_data = {mem[word_index][31:24], 24'h0};
                    endcase
                end
                `AHB_HSIZE_HALF: begin
                    if (addr_lat[1])
                        read_data = {mem[word_index][31:16], 16'h0};
                    else
                        read_data = {16'h0, mem[word_index][15:0]};
                end
                default: read_data = mem[word_index];
            endcase
        end else begin
            read_data = 32'h0;
        end

        HRDATA = read_data;
    end

    always @(*) begin
        case (size_lat)
            `AHB_HSIZE_BYTE: begin
                case (addr_lat[1:0])
                    2'b00: write_data_lane = {24'h0, HWDATA[7:0]};
                    2'b01: write_data_lane = {16'h0, HWDATA[15:8], 8'h0};
                    2'b10: write_data_lane = {8'h0, HWDATA[23:16], 16'h0};
                    default: write_data_lane = {HWDATA[31:24], 24'h0};
                endcase
            end
            `AHB_HSIZE_HALF: begin
                if (addr_lat[1])
                    write_data_lane = {HWDATA[31:16], 16'h0};
                else
                    write_data_lane = {16'h0, HWDATA[15:0]};
            end
            default: write_data_lane = HWDATA;
        endcase
    end

    always @(*) begin
        HREADY_OUT = hready_out_reg;
        HRESP      = hresp_reg;

        if (!err_phase2 && trans_valid_lat &&
            (transfer_error || (stall_req && (wait_cnt >= MAX_STALL_CYCLES-1)))) begin
            HREADY_OUT = 1'b0;
            HRESP      = `AHB_HRESP_ERROR;
        end else if (!err_phase2 && trans_valid_lat && !transfer_error &&
                     (stall_req || (wait_cnt < WAIT_STATES))) begin
            // Kéo HREADY xuống ngay trong chu kỳ đầu của pha dữ liệu.
            // Nếu chốt quyết định này, bộ chủ sẽ hoàn tất sớm một chu kỳ.
            HREADY_OUT = 1'b0;
            HRESP      = `AHB_HRESP_OKAY;
        end
    end

    // Xử lý trạng thái phản hồi và ghi RAM.
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            hready_out_reg <= 1'b1;
            hresp_reg      <= `AHB_HRESP_OKAY;
            wait_cnt    <= 4'h0;
            err_phase2  <= 1'b0;
        end else begin

            // ERROR cần hai chu kỳ theo AHB.
            if (err_phase2) begin
                hready_out_reg <= 1'b1;
                hresp_reg      <= `AHB_HRESP_OKAY;
                err_phase2 <= 1'b0;
                $display("[BỘ TỚ AHB] Chu kỳ 2 của phản hồi ERROR, địa chỉ=0x%08h, thời gian=%0t", addr_lat, $time);
            end

            else if (trans_valid_lat) begin
                // Địa chỉ, kích thước hoặc căn chỉnh không hợp lệ trả ERROR.
                if (transfer_error ||
                    (stall_req && (wait_cnt >= MAX_STALL_CYCLES-1))) begin
                    hready_out_reg <= 1'b1;
                    hresp_reg      <= `AHB_HRESP_ERROR;
                    wait_cnt       <= 4'h0;
                    err_phase2 <= 1'b1;
                    $display("[BỘ TỚ AHB] Giao dịch không hợp lệ, địa chỉ=0x%08h, kích thước=%0d, trả ERROR, thời gian=%0t",
                             addr_lat, size_lat, $time);
                end

                // Chèn chu kỳ chờ.
                else if (stall_req || (wait_cnt < WAIT_STATES)) begin
                    hready_out_reg <= 1'b0;
                    hresp_reg      <= `AHB_HRESP_OKAY;
                    wait_cnt <= wait_cnt + 1'b1;
                end

                // Thực hiện truyền.
                else begin
                    wait_cnt   <= 4'h0;
                    hready_out_reg <= 1'b1;
                    hresp_reg      <= `AHB_HRESP_OKAY;

                    if (HREADY_IN) begin
                        if (write_lat) begin
                            // Ghi RAM theo HSIZE.
                            case (size_lat)
                            `AHB_HSIZE_BYTE: begin // Byte dữ liệu
                                case (addr_lat[1:0])
                                    2'b00: mem[word_index][7:0]   <= HWDATA[7:0];
                                    2'b01: mem[word_index][15:8]  <= HWDATA[15:8];
                                    2'b10: mem[word_index][23:16] <= HWDATA[23:16];
                                    2'b11: mem[word_index][31:24] <= HWDATA[31:24];
                                endcase
                                $display("[BỘ TỚ AHB] Ghi byte tại 0x%08h = 0x%02h, thời gian=%0t",
                                         addr_lat, (write_data_lane >> (addr_lat[1:0] * 8)) & 8'hff, $time);
                            end
                            `AHB_HSIZE_HALF: begin // Nửa từ
                                if (!addr_lat[0]) begin // Kiểm tra căn chỉnh
                                    if (addr_lat[1])
                                        mem[word_index][31:16] <= HWDATA[31:16];
                                    else
                                        mem[word_index][15:0]  <= HWDATA[15:0];
                                end
                                $display("[BỘ TỚ AHB] Ghi nửa từ tại 0x%08h = 0x%04h, thời gian=%0t",
                                         addr_lat, addr_lat[1] ? HWDATA[31:16] : HWDATA[15:0], $time);
                            end
                            `AHB_HSIZE_WORD: begin // Từ
                                mem[word_index] <= HWDATA;
                                $display("[BỘ TỚ AHB] Ghi từ tại 0x%08h = 0x%08h, thời gian=%0t",
                                         addr_lat, HWDATA, $time);
                            end
                                default: begin
                                end
                            endcase
                        end else begin
                            // Đọc RAM theo HSIZE.
                            case (size_lat)
                            `AHB_HSIZE_BYTE: begin // Byte dữ liệu
                                $display("[BỘ TỚ AHB] Đọc byte tại 0x%08h = 0x%02h, thời gian=%0t",
                                         addr_lat, (read_data >> (addr_lat[1:0] * 8)) & 8'hff, $time);
                            end
                            `AHB_HSIZE_HALF: begin // Nửa từ
                                $display("[BỘ TỚ AHB] Đọc nửa từ tại 0x%08h = 0x%04h, thời gian=%0t",
                                         addr_lat, addr_lat[1] ? read_data[31:16] : read_data[15:0], $time);
                            end
                            `AHB_HSIZE_WORD: begin // Từ
                                $display("[BỘ TỚ AHB] Đọc từ tại 0x%08h = 0x%08h, thời gian=%0t",
                                         addr_lat, mem[word_index], $time);
                            end
                                default: begin
                                end
                            endcase
                        end
                    end
                end
            end else begin
                // Không được chọn thì trả OKAY.
                hready_out_reg <= 1'b1;
                hresp_reg      <= `AHB_HRESP_OKAY;
                wait_cnt       <= 4'h0;
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

    reg trans_valid_lat;
    reg err_phase2;
    reg hready_out_reg;
    reg [1:0] hresp_reg;

    assign HRDATA = 32'h0;

    always @(*) begin
        HREADY_OUT = hready_out_reg;
        HRESP      = hresp_reg;

        if (!err_phase2 && trans_valid_lat) begin
            HREADY_OUT = 1'b0;
            HRESP      = `AHB_HRESP_ERROR;
        end
    end

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            trans_valid_lat <= 1'b0;
        end else if (HREADY_IN) begin
            trans_valid_lat <= HSEL && (HTRANS == `AHB_HTRANS_NONSEQ);
        end
    end

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            hready_out_reg <= 1'b1;
            hresp_reg      <= `AHB_HRESP_OKAY;
            err_phase2 <= 1'b0;
        end else if (err_phase2) begin
            hready_out_reg <= 1'b1;
            hresp_reg      <= `AHB_HRESP_OKAY;
            err_phase2 <= 1'b0;
        end else if (trans_valid_lat) begin
            hready_out_reg <= 1'b1;
            hresp_reg      <= `AHB_HRESP_ERROR;
            err_phase2 <= 1'b1;
        end else begin
            hready_out_reg <= 1'b1;
            hresp_reg      <= `AHB_HRESP_OKAY;
        end
    end

endmodule
