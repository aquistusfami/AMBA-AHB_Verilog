`timescale 1ns / 1ps
`include "ahb_defines.v"

// Bộ tớ RAM (AHB Slave): Đọc/ghi RAM mô phỏng theo Byte, Half-word, Word, hỗ trợ chèn trễ và báo lỗi
module ahb_slave #(
    parameter MEM_DEPTH  = 256,              // Kích thước RAM (số từ 32-bit, 256 từ = 1 KiB)
    parameter BASE_ADDR  = 32'h0000_0000,    // Địa chỉ bắt đầu của RAM
    parameter WAIT_STATES = 0,               // Chu kỳ chờ tĩnh được cấu hình trước
    parameter MAX_STALL_CYCLES = 16          // Giới hạn chu kỳ chờ tối đa để ngắt bảo vệ nghẽn bus
)(
    input  wire        HCLK,
    input  wire        HRESETn,

    // Giao tiếp Bus AHB
    input  wire        HSEL,                 // Lệnh chọn bộ tớ
    input  wire [31:0] HADDR,                // Địa chỉ
    input  wire        HWRITE,               // 1: Ghi, 0: Đọc
    input  wire [2:0]  HSIZE,                // Kích thước truyền
    input  wire [2:0]  HBURST,               // Kiểu chuỗi truyền (Burst)
    input  wire [1:0]  HTRANS,               // Kiểu truyền
    input  wire [3:0]  HPROT,                // Thuộc tính bảo vệ
    input  wire [31:0] HWDATA,               // Dữ liệu ghi nhận từ Master
    input  wire        HREADY_IN,            // Sẵn sàng bus toàn cục
    input  wire        stall_req,            // Yêu cầu bắt Bus chờ từ Testbench (Stall)

    output reg  [31:0] HRDATA,               // Dữ liệu đọc trả về cho Master
    output reg         HREADY_OUT,           // Trạng thái sẵn sàng riêng của Slave
    output reg  [1:0]  HRESP                 // Phản hồi (OKAY/ERROR) trả về cho Master
);

    localparam MEM_INDEX_W   = (MEM_DEPTH <= 1) ? 1 : $clog2(MEM_DEPTH);

    // Mảng bộ nhớ RAM nội bộ
    reg [31:0] mem [0:MEM_DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 32'h0000_0000;
    end

    // Các thanh ghi chốt thông tin pha địa chỉ
    reg [31:0] addr_lat;
    reg        write_lat;
    reg [2:0]  size_lat;
    reg        trans_valid_lat;

    reg [3:0]  wait_cnt;
    reg        err_phase2;
    reg        hready_out_reg;
    reg [1:0]  hresp_reg;
    reg [31:0] read_data;
    reg [31:0] write_data_lane;

    // Các kiểm tra tính hợp lệ của địa chỉ và kích thước truyền
    wire [31:0] addr_offset = addr_lat - BASE_ADDR;
    wire [MEM_INDEX_W-1:0] word_index = addr_offset[MEM_INDEX_W+1:2];

    // Kiểm tra địa chỉ có nằm trong vùng RAM của bộ tớ
    wire        addr_valid  = (addr_lat >= BASE_ADDR) &&
                              (addr_lat < (BASE_ADDR + MEM_DEPTH * 4));

    // Kiểm tra kích thước truyền (không được lớn hơn WORD 32-bit)
    wire        size_valid  = (size_lat <= `AHB_HSIZE_MAX);

    // Kiểm tra căn chỉnh biên địa chỉ (Word chia hết cho 4, Half-word chia hết cho 2)
    wire        addr_aligned = (size_lat == `AHB_HSIZE_BYTE) ||
                               ((size_lat == `AHB_HSIZE_HALF) && !addr_lat[0]) ||
                               ((size_lat == `AHB_HSIZE_WORD) && (addr_lat[1:0] == 2'b00));

    // Lỗi xảy ra nếu vi phạm một trong các điều kiện trên
    wire        transfer_error = !addr_valid || !size_valid || !addr_aligned;

    // Chốt pha địa chỉ khi bus sẵn sàng
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_lat        <= 32'h0;
            write_lat       <= 1'b0;
            size_lat        <= `AHB_HSIZE_WORD;
            trans_valid_lat <= 1'b0;
        end else if (HREADY_IN) begin
            addr_lat        <= HADDR;
            write_lat       <= HWRITE;
            size_lat        <= HSIZE;
            trans_valid_lat <= HSEL && (HTRANS == `AHB_HTRANS_NONSEQ);
        end
    end

    // Ghép làn byte Little-endian cho dữ liệu đọc (HRDATA)
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

    // Ghép làn byte Little-endian cho dữ liệu ghi (HWDATA)
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

    // Tạo tổ hợp các tín hiệu sẵn sàng và phản hồi
    always @(*) begin
        HREADY_OUT = hready_out_reg;
        HRESP      = hresp_reg;

        // Chu kỳ đầu tiên của ERROR response: kéo thấp HREADY_OUT, trả ERROR
        if (!err_phase2 && trans_valid_lat &&
            (transfer_error || (stall_req && (wait_cnt >= MAX_STALL_CYCLES-1)))) begin
            HREADY_OUT = 1'b0;
            HRESP      = `AHB_HRESP_ERROR;
        end else if (!err_phase2 && trans_valid_lat && !transfer_error &&
                     (stall_req || (wait_cnt < WAIT_STATES))) begin
            // Đang chèn chu kỳ chờ bận: kéo thấp HREADY_OUT, trả OKAY
            HREADY_OUT = 1'b0;
            HRESP      = `AHB_HRESP_OKAY;
        end
    end

    // Thực thi Ghi RAM, chèn trễ và quản lý ERROR response 2 chu kỳ
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            hready_out_reg <= 1'b1;
            hresp_reg      <= `AHB_HRESP_OKAY;
            wait_cnt       <= 4'h0;
            err_phase2     <= 1'b0;
        end else begin

            // Chu kỳ thứ hai của phản hồi lỗi ERROR: nâng HREADY_OUT lên 1, trả OKAY chu kỳ sau
            if (err_phase2) begin
                hready_out_reg <= 1'b1;
                hresp_reg      <= `AHB_HRESP_OKAY;
                err_phase2     <= 1'b0;
                $display("[BỘ TỚ AHB] Chu kỳ 2 của phản hồi ERROR, địa chỉ=0x%08h, thời gian=%0t", addr_lat, $time);
            end

            else if (trans_valid_lat) begin
                // Phát hiện lỗi hoặc bị nghẽn quá giới hạn (timeout) -> chuyển sang báo lỗi ERROR
                if (transfer_error || (stall_req && (wait_cnt >= MAX_STALL_CYCLES-1))) begin
                    hready_out_reg <= 1'b1;
                    hresp_reg      <= `AHB_HRESP_ERROR;
                    wait_cnt       <= 4'h0;
                    err_phase2     <= 1'b1; // Kích hoạt pha 2 cho chu kỳ clock sau
                    $display("[BỘ TỚ AHB] Giao dịch không hợp lệ, địa chỉ=0x%08h, kích thước=%0d, trả ERROR, thời gian=%0t",
                             addr_lat, size_lat, $time);
                end

                // Chèn chu kỳ chờ
                else if (stall_req || (wait_cnt < WAIT_STATES)) begin
                    hready_out_reg <= 1'b0;
                    hresp_reg      <= `AHB_HRESP_OKAY;
                    wait_cnt       <= wait_cnt + 1'b1;
                end

                // Thực hiện đọc/ghi RAM thành công
                else begin
                    wait_cnt       <= 4'h0;
                    hready_out_reg <= 1'b1;
                    hresp_reg      <= `AHB_HRESP_OKAY;

                    if (HREADY_IN) begin
                        if (write_lat) begin
                            // Ghi RAM
                            case (size_lat)
                                `AHB_HSIZE_BYTE: begin
                                    case (addr_lat[1:0])
                                        2'b00: mem[word_index][7:0]   <= HWDATA[7:0];
                                        2'b01: mem[word_index][15:8]  <= HWDATA[15:8];
                                        2'b10: mem[word_index][23:16] <= HWDATA[23:16];
                                        2'b11: mem[word_index][31:24] <= HWDATA[31:24];
                                    endcase
                                    $display("[BỘ TỚ AHB] Ghi byte tại 0x%08h = 0x%02h, thời gian=%0t",
                                             addr_lat, (write_data_lane >> (addr_lat[1:0] * 8)) & 8'hff, $time);
                                end
                                `AHB_HSIZE_HALF: begin
                                    if (!addr_lat[0]) begin
                                        if (addr_lat[1])
                                            mem[word_index][31:16] <= HWDATA[31:16];
                                        else
                                            mem[word_index][15:0]  <= HWDATA[15:0];
                                    end
                                    $display("[BỘ TỚ AHB] Ghi nửa từ tại 0x%08h = 0x%04h, thời gian=%0t",
                                             addr_lat, addr_lat[1] ? HWDATA[31:16] : HWDATA[15:0], $time);
                                end
                                `AHB_HSIZE_WORD: begin
                                    mem[word_index] <= HWDATA;
                                    $display("[BỘ TỚ AHB] Ghi từ tại 0x%08h = 0x%08h, thời gian=%0t",
                                             addr_lat, HWDATA, $time);
                                end
                                default: begin
                                end
                            endcase
                        end else begin
                            // In nhật ký đọc RAM
                            case (size_lat)
                                `AHB_HSIZE_BYTE: begin
                                    $display("[BỘ TỚ AHB] Đọc byte tại 0x%08h = 0x%02h, thời gian=%0t",
                                             addr_lat, (read_data >> (addr_lat[1:0] * 8)) & 8'hff, $time);
                                end
                                `AHB_HSIZE_HALF: begin
                                    $display("[BỘ TỚ AHB] Đọc nửa từ tại 0x%08h = 0x%04h, thời gian=%0t",
                                             addr_lat, addr_lat[1] ? read_data[31:16] : read_data[15:0], $time);
                                end
                                `AHB_HSIZE_WORD: begin
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
                hready_out_reg <= 1'b1;
                hresp_reg      <= `AHB_HRESP_OKAY;
                wait_cnt       <= 4'h0;
            end
        end
    end

endmodule

// Bộ tớ mặc định: Tự động trả phản hồi ERROR 2 chu kỳ khi Master truy cập vào địa chỉ chưa được ánh xạ
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

    assign HRDATA = 32'h0; // Đọc địa chỉ trống luôn nhận 0

    // Phản hồi ERROR pha 1 (HREADY_OUT = 0, HRESP = ERROR)
    always @(*) begin
        HREADY_OUT = hready_out_reg;
        HRESP      = hresp_reg;

        if (!err_phase2 && trans_valid_lat) begin
            HREADY_OUT = 1'b0;
            HRESP      = `AHB_HRESP_ERROR;
        end
    end

    // Chốt giao dịch pha địa chỉ
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            trans_valid_lat <= 1'b0;
        end else if (HREADY_IN) begin
            trans_valid_lat <= HSEL && (HTRANS == `AHB_HTRANS_NONSEQ);
        end
    end

    reg hready_out_reg;
    reg [1:0] hresp_reg;

    // Sinh phản hồi lỗi ERROR 2 chu kỳ
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            hready_out_reg <= 1'b1;
            hresp_reg      <= `AHB_HRESP_OKAY;
            err_phase2     <= 1'b0;
        end else if (err_phase2) begin
            hready_out_reg <= 1'b1;
            hresp_reg      <= `AHB_HRESP_OKAY;
            err_phase2     <= 1'b0;
        end else if (trans_valid_lat) begin
            hready_out_reg <= 1'b1;
            hresp_reg      <= `AHB_HRESP_ERROR;
            err_phase2     <= 1'b1;
        end else begin
            hready_out_reg <= 1'b1;
            hresp_reg      <= `AHB_HRESP_OKAY;
        end
    end

endmodule
