`timescale 1ns / 1ps

module ahb_top (
    input  wire        HCLK,
    input  wire        HRESETn,

    input  wire        cmd_start_m1,
    input  wire        cmd_write_m1,
    input  wire        cmd_lock_m1,
    input  wire [31:0] cmd_addr_m1,
    input  wire [31:0] cmd_wdata_m1,
    output wire [31:0] rdata_m1,
    output wire        done_m1,
    output wire        error_m1,

    input  wire        cmd_start_m2,
    input  wire        cmd_write_m2,
    input  wire        cmd_lock_m2,
    input  wire [31:0] cmd_addr_m2,
    input  wire [31:0] cmd_wdata_m2,
    output wire [31:0] rdata_m2,
    output wire        done_m2,
    output wire        error_m2,

    input  wire        cmd_start_m3,
    input  wire        cmd_write_m3,
    input  wire        cmd_lock_m3,
    input  wire [31:0] cmd_addr_m3,
    input  wire [31:0] cmd_wdata_m3,
    output wire [31:0] rdata_m3,
    output wire        done_m3,
    output wire        error_m3,

    input  wire        stall_req_s1,
    input  wire        stall_req_s2,

    output wire [1:0]  dbg_hmaster,
    output wire [3:0]  dbg_hgrant,
    output wire        dbg_hready,
    output wire [1:0]  dbg_hresp,
    output wire [31:0] dbg_haddr,
    output wire [1:0]  dbg_htrans,
    output wire        dbg_hmastlock
);

    wire [31:0] HADDR, HWDATA, HRDATA;
    wire [1:0]  HTRANS, HRESP;
    wire        HWRITE, HREADY;
    wire [2:0]  HSIZE, HBURST;
    wire [3:0]  HPROT;
    wire [15:0] HSPLIT;

    wire [3:0]  HBUSREQ;
    wire [3:0]  HLOCK;
    wire [3:0]  HGRANT;
    wire [1:0]  HMASTER;
    wire        HMASTLOCK;

    wire hsel_s0, hsel_s1, hsel_s2, hsel_s3, hsel_def;

    wire [31:0] haddr_m0, haddr_m1, haddr_m2, haddr_m3;
    wire [31:0] hwdata_m0, hwdata_m1, hwdata_m2, hwdata_m3;
    wire [1:0]  htrans_m0, htrans_m1, htrans_m2, htrans_m3;
    wire        hwrite_m0, hwrite_m1, hwrite_m2, hwrite_m3;
    wire [2:0]  hsize_m0, hsize_m1, hsize_m2, hsize_m3;
    wire [2:0]  hburst_m0, hburst_m1, hburst_m2, hburst_m3;
    wire [3:0]  hprot_m0, hprot_m1, hprot_m2, hprot_m3;

    wire [31:0] hrdata_s0, hrdata_s1, hrdata_s2, hrdata_s3, hrdata_def;
    wire        hreadyout_s0, hreadyout_s1, hreadyout_s2, hreadyout_s3, hreadyout_def;
    wire [1:0]  hresp_s0, hresp_s1, hresp_s2, hresp_s3, hresp_def;

    assign HBUSREQ[0] = 1'b0;
    assign HLOCK[0]   = 1'b0;
    assign haddr_m0   = 32'h0;
    assign hwdata_m0  = 32'h0;
    assign htrans_m0  = 2'b00;
    assign hwrite_m0  = 1'b0;
    assign hsize_m0   = 3'b010;
    assign hburst_m0  = 3'b000;
    assign hprot_m0   = 4'b0011;

    ahb_master u_master1 (
        .HCLK(HCLK), .HRESETn(HRESETn), .HGRANT(HGRANT[1]), .HREADY(HREADY),
        .HRESP(HRESP), .HRDATA(HRDATA), .HBUSREQ(HBUSREQ[1]), .HLOCK(HLOCK[1]),
        .HADDR(haddr_m1), .HTRANS(htrans_m1), .HWRITE(hwrite_m1), .HSIZE(hsize_m1),
        .HBURST(hburst_m1), .HPROT(hprot_m1), .HWDATA(hwdata_m1),
        .cmd_start(cmd_start_m1), .cmd_addr(cmd_addr_m1), .cmd_wdata(cmd_wdata_m1),
        .cmd_write(cmd_write_m1), .cmd_lock(cmd_lock_m1),
        .rdata_out(rdata_m1), .done(done_m1), .error_out(error_m1)
    );

    ahb_master u_master2 (
        .HCLK(HCLK), .HRESETn(HRESETn), .HGRANT(HGRANT[2]), .HREADY(HREADY),
        .HRESP(HRESP), .HRDATA(HRDATA), .HBUSREQ(HBUSREQ[2]), .HLOCK(HLOCK[2]),
        .HADDR(haddr_m2), .HTRANS(htrans_m2), .HWRITE(hwrite_m2), .HSIZE(hsize_m2),
        .HBURST(hburst_m2), .HPROT(hprot_m2), .HWDATA(hwdata_m2),
        .cmd_start(cmd_start_m2), .cmd_addr(cmd_addr_m2), .cmd_wdata(cmd_wdata_m2),
        .cmd_write(cmd_write_m2), .cmd_lock(cmd_lock_m2),
        .rdata_out(rdata_m2), .done(done_m2), .error_out(error_m2)
    );

    ahb_master u_master3 (
        .HCLK(HCLK), .HRESETn(HRESETn), .HGRANT(HGRANT[3]), .HREADY(HREADY),
        .HRESP(HRESP), .HRDATA(HRDATA), .HBUSREQ(HBUSREQ[3]), .HLOCK(HLOCK[3]),
        .HADDR(haddr_m3), .HTRANS(htrans_m3), .HWRITE(hwrite_m3), .HSIZE(hsize_m3),
        .HBURST(hburst_m3), .HPROT(hprot_m3), .HWDATA(hwdata_m3),
        .cmd_start(cmd_start_m3), .cmd_addr(cmd_addr_m3), .cmd_wdata(cmd_wdata_m3),
        .cmd_write(cmd_write_m3), .cmd_lock(cmd_lock_m3),
        .rdata_out(rdata_m3), .done(done_m3), .error_out(error_m3)
    );

    ahb_arbiter u_arbiter (
        .HCLK(HCLK), .HRESETn(HRESETn), .HBUSREQ(HBUSREQ), .HLOCK(HLOCK),
        .HSPLIT(HSPLIT[3:0]), .HTRANS(HTRANS), .HBURST(HBURST), .HRESP(HRESP),
        .HREADY(HREADY), .HGRANT(HGRANT), .HMASTER(HMASTER), .HMASTLOCK(HMASTLOCK)
    );

    ahb_decoder u_decoder (
        .HADDR(HADDR), .HSEL_S0(hsel_s0), .HSEL_S1(hsel_s1),
        .HSEL_S2(hsel_s2), .HSEL_S3(hsel_s3), .HSEL_DEFAULT(hsel_def)
    );

    ahb_mux u_mux (
        .HCLK(HCLK), .HRESETn(HRESETn), .HMASTER(HMASTER), .HMASTLOCK(HMASTLOCK),
        .HSEL_S0(hsel_s0), .HSEL_S1(hsel_s1), .HSEL_S2(hsel_s2),
        .HSEL_S3(hsel_s3), .HSEL_DEFAULT(hsel_def),
        .HADDR_M0(haddr_m0), .HWDATA_M0(hwdata_m0), .HTRANS_M0(htrans_m0),
        .HWRITE_M0(hwrite_m0), .HSIZE_M0(hsize_m0), .HBURST_M0(hburst_m0), .HPROT_M0(hprot_m0),
        .HADDR_M1(haddr_m1), .HWDATA_M1(hwdata_m1), .HTRANS_M1(htrans_m1),
        .HWRITE_M1(hwrite_m1), .HSIZE_M1(hsize_m1), .HBURST_M1(hburst_m1), .HPROT_M1(hprot_m1),
        .HADDR_M2(haddr_m2), .HWDATA_M2(hwdata_m2), .HTRANS_M2(htrans_m2),
        .HWRITE_M2(hwrite_m2), .HSIZE_M2(hsize_m2), .HBURST_M2(hburst_m2), .HPROT_M2(hprot_m2),
        .HADDR_M3(haddr_m3), .HWDATA_M3(hwdata_m3), .HTRANS_M3(htrans_m3),
        .HWRITE_M3(hwrite_m3), .HSIZE_M3(hsize_m3), .HBURST_M3(hburst_m3), .HPROT_M3(hprot_m3),
        .HRDATA_S0(hrdata_s0), .HREADYOUT_S0(hreadyout_s0), .HRESP_S0(hresp_s0), .HSPLIT_S0(16'h0),
        .HRDATA_S1(hrdata_s1), .HREADYOUT_S1(hreadyout_s1), .HRESP_S1(hresp_s1), .HSPLIT_S1(16'h0),
        .HRDATA_S2(hrdata_s2), .HREADYOUT_S2(hreadyout_s2), .HRESP_S2(hresp_s2), .HSPLIT_S2(16'h0),
        .HRDATA_S3(hrdata_s3), .HREADYOUT_S3(hreadyout_s3), .HRESP_S3(hresp_s3), .HSPLIT_S3(16'h0),
        .HRDATA_DEF(hrdata_def), .HREADYOUT_DEF(hreadyout_def), .HRESP_DEF(hresp_def), .HSPLIT_DEF(16'h0),
        .HMASTER_OUT(), .HMASTLOCK_OUT(), .HADDR(HADDR), .HWDATA(HWDATA),
        .HTRANS(HTRANS), .HWRITE(HWRITE), .HSIZE(HSIZE), .HBURST(HBURST), .HPROT(HPROT),
        .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP), .HSPLIT(HSPLIT)
    );

    ahb_slave #(.BASE_ADDR(32'h0000_0000)) u_slave0 (
        .HCLK(HCLK), .HRESETn(HRESETn), .HSEL(hsel_s0), .HADDR(HADDR),
        .HWRITE(HWRITE), .HSIZE(HSIZE), .HBURST(HBURST), .HTRANS(HTRANS),
        .HPROT(HPROT), .HWDATA(HWDATA), .HREADY_IN(HREADY), .stall_req(1'b0),
        .HRDATA(hrdata_s0), .HREADY_OUT(hreadyout_s0), .HRESP(hresp_s0)
    );

    ahb_slave #(.BASE_ADDR(32'h2000_0000)) u_slave1 (
        .HCLK(HCLK), .HRESETn(HRESETn), .HSEL(hsel_s1), .HADDR(HADDR),
        .HWRITE(HWRITE), .HSIZE(HSIZE), .HBURST(HBURST), .HTRANS(HTRANS),
        .HPROT(HPROT), .HWDATA(HWDATA), .HREADY_IN(HREADY), .stall_req(stall_req_s1),
        .HRDATA(hrdata_s1), .HREADY_OUT(hreadyout_s1), .HRESP(hresp_s1)
    );

    ahb_slave #(.BASE_ADDR(32'h4000_0000)) u_slave2 (
        .HCLK(HCLK), .HRESETn(HRESETn), .HSEL(hsel_s2), .HADDR(HADDR),
        .HWRITE(HWRITE), .HSIZE(HSIZE), .HBURST(HBURST), .HTRANS(HTRANS),
        .HPROT(HPROT), .HWDATA(HWDATA), .HREADY_IN(HREADY), .stall_req(stall_req_s2),
        .HRDATA(hrdata_s2), .HREADY_OUT(hreadyout_s2), .HRESP(hresp_s2)
    );

    ahb_slave #(.BASE_ADDR(32'h6000_0000), .MEM_DEPTH(256)) u_slave3 (
        .HCLK(HCLK), .HRESETn(HRESETn), .HSEL(hsel_s3), .HADDR(HADDR),
        .HWRITE(HWRITE), .HSIZE(HSIZE), .HBURST(HBURST), .HTRANS(HTRANS),
        .HPROT(HPROT), .HWDATA(HWDATA), .HREADY_IN(HREADY), .stall_req(1'b0),
        .HRDATA(hrdata_s3), .HREADY_OUT(hreadyout_s3), .HRESP(hresp_s3)
    );

    ahb_default_slave u_default_slave (
        .HCLK(HCLK), .HRESETn(HRESETn), .HSEL(hsel_def), .HTRANS(HTRANS),
        .HREADY_IN(HREADY), .HREADY_OUT(hreadyout_def), .HRESP(hresp_def),
        .HRDATA(hrdata_def)
    );

    assign dbg_hmaster   = HMASTER;
    assign dbg_hgrant    = HGRANT;
    assign dbg_hready    = HREADY;
    assign dbg_hresp     = HRESP;
    assign dbg_haddr     = HADDR;
    assign dbg_htrans    = HTRANS;
    assign dbg_hmastlock = HMASTLOCK;

endmodule
