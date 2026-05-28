`timescale 1ns / 1ps

// Bộ mux trung tâm cho bus AHB.
//
// Sửa lỗi theo AMBA 2 AHB Specification (IHI0011A):
//
//  Fix 1 – Phản hồi hai chu kỳ (§3.9.3)
//          ERROR / RETRY / SPLIT đòi hỏi đúng hai chu kỳ:
//          chu kỳ đầu HREADY=0 + mã phản hồi, chu kỳ hai HREADY=1 + cùng mã.
//          Mux phải đóng băng HRESP và kéo HREADY xuống 0 trong chu kỳ đầu,
//          sau đó thả HREADY lên 1 trong chu kỳ hai.
//
//  Fix 2 – HMASTLOCK phải được pipeline sang pha dữ liệu (§3.11.5 / §3.11.1)
//          HMASTLOCK có cùng timing với HMASTER và các tín hiệu địa chỉ.
//          Slave SPLIT-capable cần giá trị pha dữ liệu để biết giao dịch
//          đang bị khóa; do đó cần chốt vào thanh ghi data-phase giống
//          cách HMASTER_data đã được chốt.
//
//  Lưu ý – HSPLIT OR từ các slave là ĐÚNG theo spec (§3.12.1):
//          "HSPLITx buses from each slave can be ORed together."

module ahb_mux #(
    parameter NUM_MASTERS = 4
)(
    input  wire        HCLK,
    input  wire        HRESETn,

    // Tín hiệu điều khiển từ arbiter và decoder.

    input  wire [$clog2(NUM_MASTERS)-1:0] HMASTER,
    input  wire                           HMASTLOCK,

    input  wire        HSEL_S0,
    input  wire        HSEL_S1,
    input  wire        HSEL_S2,
    input  wire        HSEL_S3,
    input  wire        HSEL_DEFAULT,

    // Master 0.

    input  wire [31:0] HADDR_M0,
    input  wire [31:0] HWDATA_M0,
    input  wire [1:0]  HTRANS_M0,
    input  wire        HWRITE_M0,
    input  wire [2:0]  HSIZE_M0,
    input  wire [2:0]  HBURST_M0,
    input  wire [3:0]  HPROT_M0,

    // Master 1.

    input  wire [31:0] HADDR_M1,
    input  wire [31:0] HWDATA_M1,
    input  wire [1:0]  HTRANS_M1,
    input  wire        HWRITE_M1,
    input  wire [2:0]  HSIZE_M1,
    input  wire [2:0]  HBURST_M1,
    input  wire [3:0]  HPROT_M1,

    // Master 2.

    input  wire [31:0] HADDR_M2,
    input  wire [31:0] HWDATA_M2,
    input  wire [1:0]  HTRANS_M2,
    input  wire        HWRITE_M2,
    input  wire [2:0]  HSIZE_M2,
    input  wire [2:0]  HBURST_M2,
    input  wire [3:0]  HPROT_M2,

    // Master 3.

    input  wire [31:0] HADDR_M3,
    input  wire [31:0] HWDATA_M3,
    input  wire [1:0]  HTRANS_M3,
    input  wire        HWRITE_M3,
    input  wire [2:0]  HSIZE_M3,
    input  wire [2:0]  HBURST_M3,
    input  wire [3:0]  HPROT_M3,

    // Slave 0.

    input  wire [31:0] HRDATA_S0,
    input  wire        HREADYOUT_S0,
    input  wire [1:0]  HRESP_S0,
    input  wire [15:0] HSPLIT_S0,

    // Slave 1.

    input  wire [31:0] HRDATA_S1,
    input  wire        HREADYOUT_S1,
    input  wire [1:0]  HRESP_S1,
    input  wire [15:0] HSPLIT_S1,

    // Slave 2.

    input  wire [31:0] HRDATA_S2,
    input  wire        HREADYOUT_S2,
    input  wire [1:0]  HRESP_S2,
    input  wire [15:0] HSPLIT_S2,

    // Slave 3.

    input  wire [31:0] HRDATA_S3,
    input  wire        HREADYOUT_S3,
    input  wire [1:0]  HRESP_S3,
    input  wire [15:0] HSPLIT_S3,

    // Slave mặc định.

    input  wire [31:0] HRDATA_DEF,
    input  wire        HREADYOUT_DEF,
    input  wire [1:0]  HRESP_DEF,
    input  wire [15:0] HSPLIT_DEF,

    // Tín hiệu phát tới slave.

    output wire [$clog2(NUM_MASTERS)-1:0] HMASTER_OUT,
    // [FIX 2] HMASTLOCK_OUT phản ánh pha dữ liệu, không phải pha địa chỉ trực tiếp.
    output wire                           HMASTLOCK_OUT,

    output wire [31:0] HADDR,
    output wire [31:0] HWDATA,
    output wire [1:0]  HTRANS,
    output wire        HWRITE,
    output wire [2:0]  HSIZE,
    output wire [2:0]  HBURST,
    output wire [3:0]  HPROT,

    // Tín hiệu trả về master và arbiter.

    output wire [31:0] HRDATA,
    output wire        HREADY,
    output wire [1:0]  HRESP,
    output wire [15:0] HSPLIT
);

// ---------------------------------------------------------------------------
// Hằng số nội bộ.
// ---------------------------------------------------------------------------

localparam TR_IDLE   = 2'b00;
localparam TR_BUSY   = 2'b01;
localparam TR_NONSEQ = 2'b10;
localparam TR_SEQ    = 2'b11;

localparam RESP_OKAY  = 2'b00;
localparam RESP_ERROR = 2'b01;
localparam RESP_RETRY = 2'b10;
localparam RESP_SPLIT = 2'b11;

localparam MASTER_W = $clog2(NUM_MASTERS);

// ---------------------------------------------------------------------------
// Tín hiệu nội bộ.
// ---------------------------------------------------------------------------

wire [1:0] htrans_int;          // HTRANS pha địa chỉ
wire [1:0] raw_hresp;           // HRESP thô từ slave đang được chọn
wire       raw_hready;          // HREADY thô từ slave đang được chọn

// ---------------------------------------------------------------------------
// Thanh ghi pipeline pha dữ liệu.
// ---------------------------------------------------------------------------

reg [MASTER_W-1:0] HMASTER_data;
reg                HMASTLOCK_data; // [FIX 2] pipeline HMASTLOCK sang pha dữ liệu
reg [1:0]          HTRANS_data;

reg HSEL_S0_data;
reg HSEL_S1_data;
reg HSEL_S2_data;
reg HSEL_S3_data;
reg HSEL_DEFAULT_data;

// ---------------------------------------------------------------------------
// [FIX 1] Thanh ghi trạng thái phản hồi hai chu kỳ.
//
// err_first_cycle: đang ở chu kỳ đầu của phản hồi ERROR/RETRY/SPLIT.
// err_resp_hold  : mã HRESP được chốt để giữ trong chu kỳ hai.
// ---------------------------------------------------------------------------

reg       err_first_cycle;
reg [1:0] err_resp_hold;

// ---------------------------------------------------------------------------
// Chốt từ pha địa chỉ sang pha dữ liệu.
// Chỉ cập nhật khi HREADY=1 (transfer hoàn tất) và không đang trong
// chu kỳ đầu của phản hồi lỗi (lúc đó bus bị đóng băng).
// ---------------------------------------------------------------------------

wire pipeline_en = raw_hready && !err_first_cycle;

always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        HMASTER_data      <= {MASTER_W{1'b0}};
        HMASTLOCK_data    <= 1'b0;          // [FIX 2]
        HTRANS_data       <= TR_IDLE;

        HSEL_S0_data      <= 1'b0;
        HSEL_S1_data      <= 1'b0;
        HSEL_S2_data      <= 1'b0;
        HSEL_S3_data      <= 1'b0;
        HSEL_DEFAULT_data <= 1'b0;
    end
    else if (pipeline_en) begin
        HMASTER_data      <= HMASTER;
        HMASTLOCK_data    <= HMASTLOCK;     // [FIX 2]
        HTRANS_data       <= htrans_int;

        HSEL_S0_data      <= HSEL_S0;
        HSEL_S1_data      <= HSEL_S1;
        HSEL_S2_data      <= HSEL_S2;
        HSEL_S3_data      <= HSEL_S3;
        HSEL_DEFAULT_data <= HSEL_DEFAULT;
    end
end

// ---------------------------------------------------------------------------
// [FIX 1] Logic phản hồi hai chu kỳ (§3.9.3).
//
// Khi slave trả về HRESP != OKAY, chu kỳ đầu tiên:
//   - HREADY phải là 0 (extend thêm một chu kỳ).
//   - HRESP giữ nguyên mã lỗi.
// Chu kỳ thứ hai:
//   - HREADY = 1 (từ slave hoặc mux thả ra).
//   - HRESP giữ cùng mã lỗi.
//
// Mux chịu trách nhiệm đảm bảo giao thức này bất kể slave có tuân thủ
// đúng hay không.
// ---------------------------------------------------------------------------

wire non_okay_resp = (raw_hresp != RESP_OKAY);

always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        err_first_cycle <= 1'b0;
        err_resp_hold   <= RESP_OKAY;
    end
    else begin
        if (!err_first_cycle) begin
            // Phát hiện chu kỳ đầu của phản hồi lỗi/RETRY/SPLIT:
            // slave phải đang sẵn sàng phản hồi (raw_hready=1 chứng tỏ slave
            // đã xong wait states) nhưng trả về non-OKAY.
            if (raw_hready && non_okay_resp) begin
                err_first_cycle <= 1'b1;
                err_resp_hold   <= raw_hresp;
            end
        end
        else begin
            // Chu kỳ hai: thả ra, quay về trạng thái bình thường.
            err_first_cycle <= 1'b0;
            err_resp_hold   <= RESP_OKAY;
        end
    end
end

// ---------------------------------------------------------------------------
// Mux địa chỉ và điều khiển từ master (pha địa chỉ – dùng HMASTER trực tiếp).
// ---------------------------------------------------------------------------

assign HMASTER_OUT  = HMASTER;
// [FIX 2] Phát HMASTLOCK_data (pha dữ liệu) thay vì HMASTLOCK (pha địa chỉ).
assign HMASTLOCK_OUT = HMASTLOCK_data;

assign HADDR =
        (HMASTER == 2'd0) ? HADDR_M0 :
        (HMASTER == 2'd1) ? HADDR_M1 :
        (HMASTER == 2'd2) ? HADDR_M2 :
        (HMASTER == 2'd3) ? HADDR_M3 :
                            32'd0;

assign htrans_int =
        (HMASTER == 2'd0) ? HTRANS_M0 :
        (HMASTER == 2'd1) ? HTRANS_M1 :
        (HMASTER == 2'd2) ? HTRANS_M2 :
        (HMASTER == 2'd3) ? HTRANS_M3 :
                            TR_IDLE;

assign HTRANS = htrans_int;

assign HWRITE =
        (HMASTER == 2'd0) ? HWRITE_M0 :
        (HMASTER == 2'd1) ? HWRITE_M1 :
        (HMASTER == 2'd2) ? HWRITE_M2 :
        (HMASTER == 2'd3) ? HWRITE_M3 :
                            1'b0;

assign HSIZE =
        (HMASTER == 2'd0) ? HSIZE_M0 :
        (HMASTER == 2'd1) ? HSIZE_M1 :
        (HMASTER == 2'd2) ? HSIZE_M2 :
        (HMASTER == 2'd3) ? HSIZE_M3 :
                            3'b000;

assign HBURST =
        (HMASTER == 2'd0) ? HBURST_M0 :
        (HMASTER == 2'd1) ? HBURST_M1 :
        (HMASTER == 2'd2) ? HBURST_M2 :
        (HMASTER == 2'd3) ? HBURST_M3 :
                            3'b000;

assign HPROT =
        (HMASTER == 2'd0) ? HPROT_M0 :
        (HMASTER == 2'd1) ? HPROT_M1 :
        (HMASTER == 2'd2) ? HPROT_M2 :
        (HMASTER == 2'd3) ? HPROT_M3 :
                            4'b0011;

// ---------------------------------------------------------------------------
// Mux dữ liệu ghi theo pha dữ liệu (dùng HMASTER_data – đúng spec §3.11.3).
// ---------------------------------------------------------------------------

assign HWDATA =
        (HMASTER_data == 2'd0) ? HWDATA_M0 :
        (HMASTER_data == 2'd1) ? HWDATA_M1 :
        (HMASTER_data == 2'd2) ? HWDATA_M2 :
        (HMASTER_data == 2'd3) ? HWDATA_M3 :
                                 32'd0;

// ---------------------------------------------------------------------------
// Mux phản hồi từ slave (pha dữ liệu).
// ---------------------------------------------------------------------------

assign HRDATA =
        (HSEL_S0_data)      ? HRDATA_S0  :
        (HSEL_S1_data)      ? HRDATA_S1  :
        (HSEL_S2_data)      ? HRDATA_S2  :
        (HSEL_S3_data)      ? HRDATA_S3  :
        (HSEL_DEFAULT_data) ? HRDATA_DEF :
                              32'd0;

// Tín hiệu raw trước khi áp dụng logic hai chu kỳ.
assign raw_hready =
        (HSEL_S0_data)      ? HREADYOUT_S0  :
        (HSEL_S1_data)      ? HREADYOUT_S1  :
        (HSEL_S2_data)      ? HREADYOUT_S2  :
        (HSEL_S3_data)      ? HREADYOUT_S3  :
        (HSEL_DEFAULT_data) ? HREADYOUT_DEF :
                              1'b1;

assign raw_hresp =
        (HSEL_S0_data)      ? HRESP_S0  :
        (HSEL_S1_data)      ? HRESP_S1  :
        (HSEL_S2_data)      ? HRESP_S2  :
        (HSEL_S3_data)      ? HRESP_S3  :
        (HSEL_DEFAULT_data) ? HRESP_DEF :
                              RESP_OKAY;

// ---------------------------------------------------------------------------
// [FIX 1] Xuất HREADY và HRESP tuân thủ giao thức hai chu kỳ (§3.9.3):
//
//  - Trong chu kỳ đầu (err_first_cycle=1): buộc HREADY=0 và giữ HRESP.
//  - Trong chu kỳ hai (err_first_cycle đã về 0, nhưng err_resp_hold vẫn
//    còn từ cycle trước): HREADY=raw_hready (slave thả lên 1), HRESP giữ.
//  - Trường hợp bình thường (OKAY): pass-through.
//
// Để đảm bảo HRESP nhất quán trong cả hai chu kỳ ta dùng err_resp_hold
// khi đang trong first cycle, và khi first_cycle kết thúc ta cần tiếp tục
// giữ err_resp_hold một cycle nữa (cycle hai). Vì err_resp_hold chỉ clear
// vào đầu cycle tiếp theo của err_first_cycle=1, tức là cycle hai vẫn thấy
// err_resp_hold còn giá trị lỗi.
// ---------------------------------------------------------------------------

assign HREADY = err_first_cycle ? 1'b0        : raw_hready;
assign HRESP  = err_first_cycle ? err_resp_hold
              : (err_resp_hold != RESP_OKAY)  ? err_resp_hold  // cycle hai
              :                                 raw_hresp;

// ---------------------------------------------------------------------------
// HSPLIT: OR tất cả slave – đúng theo spec §3.12.1.
// ---------------------------------------------------------------------------

assign HSPLIT = HSPLIT_S0 | HSPLIT_S1 | HSPLIT_S2 | HSPLIT_S3 | HSPLIT_DEF;

endmodule
