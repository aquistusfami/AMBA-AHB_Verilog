`timescale 1ns / 1ps
`include "ahb_defines.v"

// Bộ ghép kênh trung tâm cho bus AHB.

module ahb_mux #(
    parameter NUM_MASTERS = 4
)(
    input  wire        HCLK,
    input  wire        HRESETn,

    // Tín hiệu điều khiển từ bộ phân xử và bộ giải mã.

    input  wire [$clog2(NUM_MASTERS)-1:0] HMASTER,

    input  wire        HSEL_S0,
    input  wire        HSEL_S1,
    input  wire        HSEL_S2,
    input  wire        HSEL_S3,
    input  wire        HSEL_DEFAULT,

    // Bộ chủ 0.

    input  wire [31:0] HADDR_M0,
    input  wire [31:0] HWDATA_M0,
    input  wire [1:0]  HTRANS_M0,
    input  wire        HWRITE_M0,
    input  wire [2:0]  HSIZE_M0,
    input  wire [2:0]  HBURST_M0,
    input  wire [3:0]  HPROT_M0,

    // Bộ chủ 1.

    input  wire [31:0] HADDR_M1,
    input  wire [31:0] HWDATA_M1,
    input  wire [1:0]  HTRANS_M1,
    input  wire        HWRITE_M1,
    input  wire [2:0]  HSIZE_M1,
    input  wire [2:0]  HBURST_M1,
    input  wire [3:0]  HPROT_M1,

    // Bộ chủ 2.

    input  wire [31:0] HADDR_M2,
    input  wire [31:0] HWDATA_M2,
    input  wire [1:0]  HTRANS_M2,
    input  wire        HWRITE_M2,
    input  wire [2:0]  HSIZE_M2,
    input  wire [2:0]  HBURST_M2,
    input  wire [3:0]  HPROT_M2,

    // Bộ chủ 3.

    input  wire [31:0] HADDR_M3,
    input  wire [31:0] HWDATA_M3,
    input  wire [1:0]  HTRANS_M3,
    input  wire        HWRITE_M3,
    input  wire [2:0]  HSIZE_M3,
    input  wire [2:0]  HBURST_M3,
    input  wire [3:0]  HPROT_M3,

    // Bộ tớ 0.

    input  wire [31:0] HRDATA_S0,
    input  wire        HREADYOUT_S0,
    input  wire [1:0]  HRESP_S0,

    // Bộ tớ 1.

    input  wire [31:0] HRDATA_S1,
    input  wire        HREADYOUT_S1,
    input  wire [1:0]  HRESP_S1,

    // Bộ tớ 2.

    input  wire [31:0] HRDATA_S2,
    input  wire        HREADYOUT_S2,
    input  wire [1:0]  HRESP_S2,

    // Bộ tớ 3.

    input  wire [31:0] HRDATA_S3,
    input  wire        HREADYOUT_S3,
    input  wire [1:0]  HRESP_S3,

    // Bộ tớ mặc định.

    input  wire [31:0] HRDATA_DEF,
    input  wire        HREADYOUT_DEF,
    input  wire [1:0]  HRESP_DEF,

    // Tín hiệu phát tới bộ tớ.

    output wire [31:0] HADDR,
    output wire [31:0] HWDATA,
    output wire [1:0]  HTRANS,
    output wire        HWRITE,
    output wire [2:0]  HSIZE,
    output wire [2:0]  HBURST,
    output wire [3:0]  HPROT,

    // Tín hiệu trả về bộ chủ và bộ phân xử.

    output wire [31:0] HRDATA,
    output wire        HREADY,
    output wire [1:0]  HRESP
);

localparam MASTER_W = $clog2(NUM_MASTERS);

// Tín hiệu nội bộ.

wire hready_global;
wire [1:0] htrans_int; // HTRANS pha địa chỉ

// Thanh ghi đường ống của pha dữ liệu.

reg [MASTER_W-1:0] HMASTER_data;

reg HSEL_S0_data;
reg HSEL_S1_data;
reg HSEL_S2_data;
reg HSEL_S3_data;
reg HSEL_DEFAULT_data;

// Chốt từ pha địa chỉ sang pha dữ liệu.

always @(posedge HCLK or negedge HRESETn) begin

    if (!HRESETn) begin

        HMASTER_data      <= {MASTER_W{1'b0}};
        HSEL_S0_data      <= 1'b0;
        HSEL_S1_data      <= 1'b0;
        HSEL_S2_data      <= 1'b0;
        HSEL_S3_data      <= 1'b0;
        HSEL_DEFAULT_data <= 1'b0;

    end
    else if (hready_global) begin

        HMASTER_data      <= HMASTER;
        HSEL_S0_data      <= HSEL_S0;
        HSEL_S1_data      <= HSEL_S1;
        HSEL_S2_data      <= HSEL_S2;
        HSEL_S3_data      <= HSEL_S3;
        HSEL_DEFAULT_data <= HSEL_DEFAULT;

    end
end

// Ghép kênh địa chỉ và điều khiển từ bộ chủ.

assign HADDR =
        (HMASTER == 0) ? HADDR_M0 :
        (HMASTER == 1) ? HADDR_M1 :
        (HMASTER == 2) ? HADDR_M2 :
        (HMASTER == 3) ? HADDR_M3 :
                         32'd0;

assign htrans_int =
        (HMASTER == 0) ? HTRANS_M0 :
        (HMASTER == 1) ? HTRANS_M1 :
        (HMASTER == 2) ? HTRANS_M2 :
        (HMASTER == 3) ? HTRANS_M3 :
                         `AHB_HTRANS_IDLE;

assign HTRANS = htrans_int;

assign HWRITE =
        (HMASTER == 0) ? HWRITE_M0 :
        (HMASTER == 1) ? HWRITE_M1 :
        (HMASTER == 2) ? HWRITE_M2 :
        (HMASTER == 3) ? HWRITE_M3 :
                         1'b0;

assign HSIZE =
        (HMASTER == 0) ? HSIZE_M0 :
        (HMASTER == 1) ? HSIZE_M1 :
        (HMASTER == 2) ? HSIZE_M2 :
        (HMASTER == 3) ? HSIZE_M3 :
                         3'b000;

assign HBURST =
        (HMASTER == 0) ? HBURST_M0 :
        (HMASTER == 1) ? HBURST_M1 :
        (HMASTER == 2) ? HBURST_M2 :
        (HMASTER == 3) ? HBURST_M3 :
                         3'b000;

assign HPROT =
        (HMASTER == 0) ? HPROT_M0 :
        (HMASTER == 1) ? HPROT_M1 :
        (HMASTER == 2) ? HPROT_M2 :
        (HMASTER == 3) ? HPROT_M3 :
                         4'b0011;

// Ghép kênh dữ liệu ghi theo pha dữ liệu.

assign HWDATA =
        (HMASTER_data == 0) ? HWDATA_M0 :
        (HMASTER_data == 1) ? HWDATA_M1 :
        (HMASTER_data == 2) ? HWDATA_M2 :
        (HMASTER_data == 3) ? HWDATA_M3 :
                              32'd0;

// Ghép kênh phản hồi từ bộ tớ.

assign HRDATA =
        (HSEL_S0_data)      ? HRDATA_S0 :
        (HSEL_S1_data)      ? HRDATA_S1 :
        (HSEL_S2_data)      ? HRDATA_S2 :
        (HSEL_S3_data)      ? HRDATA_S3 :
        (HSEL_DEFAULT_data) ? HRDATA_DEF :
                              32'd0;

assign hready_global =
        (HSEL_S0_data)      ? HREADYOUT_S0 :
        (HSEL_S1_data)      ? HREADYOUT_S1 :
        (HSEL_S2_data)      ? HREADYOUT_S2 :
        (HSEL_S3_data)      ? HREADYOUT_S3 :
        (HSEL_DEFAULT_data) ? HREADYOUT_DEF :
                              1'b1;

assign HREADY = hready_global;

    // Chọn phản hồi theo bộ tớ của pha dữ liệu.
    assign HRESP =
        (HSEL_S0_data)      ? HRESP_S0 :
        (HSEL_S1_data)      ? HRESP_S1 :
        (HSEL_S2_data)      ? HRESP_S2 :
        (HSEL_S3_data)      ? HRESP_S3 :
        (HSEL_DEFAULT_data) ? HRESP_DEF :
                              `AHB_HRESP_OKAY;

endmodule
