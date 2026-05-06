`timescale 1ns / 1ps
`include "ahb_defines.v"

module ahb_slave (
    input  wire        HCLK,
    input  wire        HRESETn,
    
    // Tín hiệu chuẩn AHB
    input  wire        HSEL,
    input  wire [31:0] HADDR,
    input  wire [1:0]  HTRANS,
    input  wire        HWRITE,
    input  wire [2:0]  HSIZE,
    input  wire [31:0] HWDATA,
    input  wire        HREADY_IN, // HREADY của toàn hệ thống
    
    output reg         HREADY_OUT,
    output reg  [1:0]  HRESP,
    output reg  [31:0] HRDATA,

    // Tín hiệu dành riêng cho việc Test (Tạo Wait States)
    input  wire        stall_req 
);

    // Bộ nhớ RAM nội bộ (256 words = 1KB)
    reg [31:0] memory [0:255];

    // Thanh ghi lưu vết cho Data Phase
    reg        r_write_en;
    reg [31:0] r_addr;
    reg        r_active;

    // 1. Lấy mẫu ở Pha Địa chỉ (Address Phase)
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            r_write_en <= 1'b0;
            r_addr     <= 32'd0;
            r_active   <= 1'b0;
        end else if (HREADY_IN) begin // Chỉ nhận lệnh mới khi Bus đang rảnh
            if (HSEL && (HTRANS == `AHB_HTRANS_NONSEQ || HTRANS == `AHB_HTRANS_SEQ)) begin
                r_write_en <= HWRITE;
                r_addr     <= HADDR;
                r_active   <= 1'b1;
            end else begin
                r_active   <= 1'b0;
            end
        end
    end

    // 2. Thực thi ở Pha Dữ liệu (Data Phase)
    wire [7:0] word_idx = r_addr[9:2]; // Dịch 2 bit vì là word-aligned (4 bytes)

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HRDATA     <= 32'd0;
            HREADY_OUT <= 1'b1;
            HRESP      <= `AHB_HRESP_OKAY;
        end else begin
            // Mặc định luôn sẵn sàng và OK
            HREADY_OUT <= 1'b1;
            HRESP      <= `AHB_HRESP_OKAY;

            if (r_active) begin
                if (stall_req) begin
                    // Giả lập Wait State: Ép HREADY_OUT = 0 để bắt Master chờ
                    HREADY_OUT <= 1'b0; 
                end else begin
                    // Thực hiện Ghi hoặc Đọc
                    HREADY_OUT <= 1'b1;
                    if (r_write_en) begin
                        memory[word_idx] <= HWDATA;
                    end else begin
                        HRDATA <= memory[word_idx];
                    end
                end
            end
        end
    end

endmodule
