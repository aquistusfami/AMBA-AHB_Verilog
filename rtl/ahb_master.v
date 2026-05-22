`timescale 1ns / 1ps

module ahb_master (
    input  wire        HCLK,
    input  wire        HRESETn,

    input  wire        HGRANT,
    input  wire        HREADY,
    input  wire [1:0]  HRESP,
    input  wire [31:0] HRDATA,

    output reg         HBUSREQ,
    output reg         HLOCK,
    output reg  [31:0] HADDR,
    output reg  [1:0]  HTRANS,
    output reg         HWRITE,
    output reg  [2:0]  HSIZE,
    output reg  [2:0]  HBURST,
    output reg  [3:0]  HPROT,
    output reg  [31:0] HWDATA,

    input  wire        cmd_start,
    input  wire [31:0] cmd_addr,
    input  wire [31:0] cmd_wdata,
    input  wire        cmd_write,
    input  wire        cmd_lock,
    input  wire [2:0]  cmd_size,

    output reg  [31:0] rdata_out,  // Dữ liệu đọc
    output reg         done,       // Giữ 1 sau khi hoàn tất
    output reg         error_out   // Giữ 1 sau khi lỗi
);

    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_NONSEQ = 2'b10;

    localparam HRESP_OKAY  = 2'b00;
    localparam HRESP_ERROR = 2'b01;

    localparam HBURST_SINGLE = 3'b000;
    localparam HSIZE_WORD    = 3'b010;

    localparam [2:0]
        ST_IDLE       = 3'd0,
        ST_REQ        = 3'd1,
        ST_ADDR       = 3'd2,
        ST_DATA       = 3'd3;

    reg [2:0]  state;
    reg [31:0] addr_lat;
    reg [31:0] wdata_lat;
    reg        write_lat;
    reg        lock_lat;
    reg [2:0]  size_lat;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state     <= ST_IDLE;
            addr_lat  <= 32'h0;
            wdata_lat <= 32'h0;
            write_lat <= 1'b0;
            lock_lat  <= 1'b0;
            size_lat  <= HSIZE_WORD;
            HBUSREQ   <= 1'b0;
            HLOCK     <= 1'b0;
            HADDR     <= 32'h0;
            HTRANS    <= HTRANS_IDLE;
            HWRITE    <= 1'b0;
            HSIZE     <= HSIZE_WORD;
            HBURST    <= HBURST_SINGLE;
            HPROT     <= 4'b0011;
            HWDATA    <= 32'h0;
            rdata_out <= 32'h0;
            done      <= 1'b0;
            error_out <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    HBUSREQ <= 1'b0;
                    HLOCK   <= 1'b0;
                    HTRANS  <= HTRANS_IDLE;
                    HWRITE  <= 1'b0;

                    if (cmd_start) begin
                        addr_lat  <= cmd_addr;
                        wdata_lat <= cmd_wdata;
                        write_lat <= cmd_write;
                        lock_lat  <= cmd_lock;
                        size_lat  <= cmd_size;
                        HBUSREQ   <= 1'b1;
                        HLOCK     <= cmd_lock;
                        done      <= 1'b0;
                        error_out <= 1'b0;
                        state     <= ST_REQ;
                    end
                end

                ST_REQ: begin
                    HBUSREQ <= 1'b1;
                    HLOCK   <= lock_lat;
                    HTRANS  <= HTRANS_IDLE;

                    if (HGRANT && HREADY) begin
                        HADDR  <= addr_lat;
                        HWRITE <= write_lat;
                        HSIZE  <= size_lat;
                        HBURST <= HBURST_SINGLE;
                        HPROT  <= 4'b0011;
                        HTRANS <= HTRANS_NONSEQ;
                        HWDATA <= wdata_lat;
                        state  <= ST_ADDR;
                    end
                end

                ST_ADDR: begin
                    HADDR  <= addr_lat;
                    HWRITE <= write_lat;
                    HSIZE  <= size_lat;
                    HBURST <= HBURST_SINGLE;
                    HPROT  <= 4'b0011;
                    HTRANS <= HTRANS_NONSEQ;
                    HWDATA <= wdata_lat;
                    HLOCK  <= lock_lat;

                    if (HREADY) begin
                        HTRANS  <= HTRANS_IDLE;
                        HBUSREQ <= 1'b0;
                        state   <= ST_DATA;
                    end
                end

                ST_DATA: begin
                    HTRANS <= HTRANS_IDLE;
                    HWDATA <= wdata_lat;
                    HLOCK  <= lock_lat;

                    if (HREADY) begin
                        if (HRESP == HRESP_ERROR) begin
                            error_out <= 1'b1;
                            HLOCK     <= 1'b0;
                            HBUSREQ   <= 1'b0;
                            state     <= ST_IDLE;
                        end else begin
                            if (!write_lat)
                                rdata_out <= HRDATA;
                            done  <= 1'b1;
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
