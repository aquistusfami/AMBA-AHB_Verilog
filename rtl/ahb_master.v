`timescale 1ns / 1ps
`include "ahb_defines.v"

// Bộ chủ AHB (AHB Master): Nhận lệnh điều khiển từ Testbench/CPU để thực hiện giao dịch trên Bus
module ahb_master (
    input  wire        HCLK,
    input  wire        HRESETn,

    // Tín hiệu kết nối Bus AHB
    input  wire        HGRANT,       // Được cấp Bus hay chưa
    input  wire        HREADY,       // Bus sẵn sàng
    input  wire [1:0]  HRESP,        // Phản hồi từ Slave (OKAY/ERROR)
    input  wire [31:0] HRDATA,       // Dữ liệu đọc về từ Slave

    output reg         HBUSREQ,      // Yêu cầu cấp Bus
    output reg         HLOCK,        // Khóa Bus
    output reg  [31:0] HADDR,        // Địa chỉ Bus
    output reg  [1:0]  HTRANS,       // Kiểu truyền
    output reg         HWRITE,       // Hướng truyền (1: Ghi, 0: Đọc)
    output reg  [2:0]  HSIZE,        // Kích thước truyền
    output reg  [2:0]  HBURST,       // Kiểu burst (mặc định SINGLE)
    output reg  [3:0]  HPROT,        // Bảo vệ Bus
    output reg  [31:0] HWDATA,       // Dữ liệu ghi xuống Slave

    // Giao diện nhận lệnh điều khiển (ví dụ từ Testbench)
    input  wire        cmd_start,    // Bắt đầu giao dịch
    input  wire [31:0] cmd_addr,     // Địa chỉ đích
    input  wire [31:0] cmd_wdata,    // Dữ liệu ghi
    input  wire        cmd_write,    // 1: Ghi, 0: Đọc
    input  wire        cmd_lock,     // Yêu cầu khóa
    input  wire [2:0]  cmd_size,     // Kích thước dữ liệu

    // Kết quả trả về
    output reg  [31:0] rdata_out,    // Dữ liệu đọc được
    output reg         done,         // Báo giao dịch thành công (xung 1 chu kỳ)
    output reg         error_out     // Báo giao dịch bị lỗi (xung 1 chu kỳ)
);

    // Máy trạng thái hữu hạn (FSM)
    localparam [2:0]
        ST_IDLE       = 3'd0,  // Rỗi
        ST_REQ        = 3'd1,  // Đợi cấp bus
        ST_ADDR       = 3'd2,  // Pha địa chỉ
        ST_DATA       = 3'd3;  // Pha dữ liệu

    reg [2:0]  state;
    reg [31:0] addr_lat;
    reg [31:0] wdata_lat;
    reg        write_lat;
    reg        lock_lat;
    reg [2:0]  size_lat;

    // Quản lý máy trạng thái FSM điều khiển giao dịch AHB
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state     <= ST_IDLE;
            addr_lat  <= 32'h0;
            wdata_lat <= 32'h0;
            write_lat <= 1'b0;
            lock_lat  <= 1'b0;
            size_lat  <= `AHB_HSIZE_WORD;
            
            HBUSREQ   <= 1'b0;
            HLOCK     <= 1'b0;
            HADDR     <= 32'h0;
            HTRANS    <= `AHB_HTRANS_IDLE;
            HWRITE    <= 1'b0;
            HSIZE     <= `AHB_HSIZE_WORD;
            HBURST    <= `AHB_HBURST_SINGLE;
            HPROT     <= 4'b0011;
            HWDATA    <= 32'h0;
            
            rdata_out <= 32'h0;
            done      <= 1'b0;
            error_out <= 1'b0;
        end else begin
            case (state)
                // Chờ nhận lệnh từ Testbench
                ST_IDLE: begin
                    HBUSREQ <= 1'b0;
                    HLOCK   <= 1'b0;
                    HTRANS  <= `AHB_HTRANS_IDLE;
                    HWRITE  <= 1'b0;

                    if (cmd_start) begin
                        addr_lat  <= cmd_addr;
                        wdata_lat <= cmd_wdata;
                        write_lat <= cmd_write;
                        lock_lat  <= cmd_lock;
                        size_lat  <= cmd_size;
                        
                        HBUSREQ   <= 1'b1;  // Yêu cầu cấp Bus
                        HLOCK     <= cmd_lock;
                        done      <= 1'b0;
                        error_out <= 1'b0;
                        state     <= ST_REQ;
                    end
                end

                // Chờ cấp bus từ Arbiter
                ST_REQ: begin
                    HLOCK   <= lock_lat;
                    HTRANS  <= `AHB_HTRANS_IDLE;
                    
                    if (HGRANT && HREADY) begin
                        HBUSREQ <= 1'b0;
                        HADDR  <= addr_lat;
                        HWRITE <= write_lat;
                        HSIZE  <= size_lat;
                        HBURST <= `AHB_HBURST_SINGLE;
                        HPROT  <= 4'b0011;
                        HTRANS <= `AHB_HTRANS_NONSEQ; // Bắt đầu truyền dữ liệu đơn
                        HWDATA <= wdata_lat;
                        state  <= ST_ADDR;
                    end else begin
                        HBUSREQ <= 1'b1;
                    end
                end
                
                // Pha địa chỉ (Address Phase)
                ST_ADDR: begin
                    HADDR  <= addr_lat;
                    HWRITE <= write_lat;
                    HSIZE  <= size_lat;
                    HBURST <= `AHB_HBURST_SINGLE;
                    HPROT  <= 4'b0011;
                    HTRANS <= `AHB_HTRANS_NONSEQ;
                    HWDATA <= wdata_lat;
                    HLOCK  <= lock_lat;

                    if (HREADY) begin
                        HTRANS  <= `AHB_HTRANS_IDLE;
                        HBUSREQ <= 1'b0;
                        state   <= ST_DATA;
                    end
                end

                // Pha dữ liệu (Data Phase)
                ST_DATA: begin
                    HTRANS <= `AHB_HTRANS_IDLE;
                    HWDATA <= wdata_lat;
                    HLOCK  <= lock_lat;

                    if (HREADY) begin
                        if (HRESP == `AHB_HRESP_ERROR) begin
                            error_out <= 1'b1;         // Slave báo lỗi giao dịch
                            HLOCK     <= 1'b0;
                            HBUSREQ   <= 1'b0;
                            state     <= ST_IDLE;
                        end else begin
                            if (!write_lat)
                                rdata_out <= HRDATA;  // Lấy dữ liệu đọc về
                            done  <= 1'b1;            // Báo hoàn thành giao dịch thành công
                            HLOCK <= 1'b0;
                            state <= ST_IDLE;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
