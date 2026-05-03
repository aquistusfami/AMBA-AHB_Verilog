`timescale 1ns / 1ps

module ahb_mux (
    input  wire        HCLK,
    input  wire        HRESETn,

    // =========================================================================
    // TÍN HIỆU ĐIỀU KHIỂN TỪ ARBITER VÀ DECODER (Control Signals)
    // =========================================================================
    input  wire [3:0]  HMASTER,       // ID của Master hiện tại từ Arbiter
    
    input  wire        HSEL_S0,       // Tín hiệu chọn Slave 0 từ Decoder
    input  wire        HSEL_S1,       // Tín hiệu chọn Slave 1 từ Decoder
    input  wire        HSEL_S2,       // Tín hiệu chọn Slave 2 từ Decoder
    input  wire        HSEL_S3,       // Tín hiệu chọn Slave 3 từ Decoder
    input  wire        HSEL_DEFAULT,  // Tín hiệu chọn Default Slave từ Decoder

    // =========================================================================
    // LUỒNG TÍN HIỆU TỪ CÁC MASTER (Inputs from Masters)
    // =========================================================================
    // Master 0
    input  wire [31:0] HADDR_M0,
    input  wire [31:0] HWDATA_M0,
    input  wire [1:0]  HTRANS_M0,
    input  wire        HWRITE_M0,
    // Master 1
    input  wire [31:0] HADDR_M1,
    input  wire [31:0] HWDATA_M1,
    input  wire [1:0]  HTRANS_M1,
    input  wire        HWRITE_M1,
    // Master 2
    input  wire [31:0] HADDR_M2,
    input  wire [31:0] HWDATA_M2,
    input  wire [1:0]  HTRANS_M2,
    input  wire        HWRITE_M2,
    // Master 3
    input  wire [31:0] HADDR_M3,
    input  wire [31:0] HWDATA_M3,
    input  wire [1:0]  HTRANS_M3,
    input  wire        HWRITE_M3,

    // =========================================================================
    // LUỒNG TÍN HIỆU TỪ CÁC SLAVE (Inputs from Slaves)
    // =========================================================================
    // Slave 0
    input  wire [31:0] HRDATA_S0,
    input  wire        HREADYOUT_S0,
    input  wire [1:0]  HRESP_S0,
    // Slave 1
    input  wire [31:0] HRDATA_S1,
    input  wire        HREADYOUT_S1,
    input  wire [1:0]  HRESP_S1,
    // Slave 2
    input  wire [31:0] HRDATA_S2,
    input  wire        HREADYOUT_S2,
    input  wire [1:0]  HRESP_S2,
    // Slave 3
    input  wire [31:0] HRDATA_S3,
    input  wire        HREADYOUT_S3,
    input  wire [1:0]  HRESP_S3,
    // Default Slave
    input  wire [31:0] HRDATA_DEF,
    input  wire        HREADYOUT_DEF,
    input  wire [1:0]  HRESP_DEF,

    // =========================================================================
    // TÍN HIỆU XUẤT RA TOÀN HỆ THỐNG (Broadcast Outputs)
    // =========================================================================
    // Gửi tới tất cả Slaves
    output reg  [31:0] HADDR,
    output reg  [31:0] HWDATA,
    output reg  [1:0]  HTRANS,
    output reg         HWRITE,
    
    // Gửi tới tất cả Masters
    output reg  [31:0] HRDATA,
    output reg         HREADY,
    output reg  [1:0]  HRESP
);

    // =========================================================================
    // 1. THANH GHI LƯU VẾT TẠO TRỄ (PIPELINE REGISTERS)
    // =========================================================================
    // Các thanh ghi này giải quyết triệt để hiện tượng lệch pha Dữ liệu/Địa chỉ
    reg [3:0] HMASTER_data;
    reg       HSEL_S0_data;
    reg       HSEL_S1_data;
    reg       HSEL_S2_data;
    reg       HSEL_S3_data;
    reg       HSEL_DEFAULT_data;

    // Chốt chặn HREADY: Thanh ghi trễ chỉ được cập nhật khi Slave báo rảnh (HREADY = 1)
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HMASTER_data      <= 4'd0;
            HSEL_S0_data      <= 1'b0;
            HSEL_S1_data      <= 1'b0;
            HSEL_S2_data      <= 1'b0;
            HSEL_S3_data      <= 1'b0;
            HSEL_DEFAULT_data <= 1'b1; // Mặc định trỏ về Default Slave
        end else if (HREADY) begin
            HMASTER_data      <= HMASTER;
            HSEL_S0_data      <= HSEL_S0;
            HSEL_S1_data      <= HSEL_S1;
            HSEL_S2_data      <= HSEL_S2;
            HSEL_S3_data      <= HSEL_S3;
            HSEL_DEFAULT_data <= HSEL_DEFAULT;
        end
    end

    // =========================================================================
    // 2. LUỒNG MASTER-TO-SLAVE (M2S MUX)
    // =========================================================================
    
    // 2A. MUX ĐỊA CHỈ & ĐIỀU KHIỂN (Sử dụng HMASTER tức thời)
    always @(*) begin
        case (HMASTER)
            4'd0: begin HADDR = HADDR_M0; HTRANS = HTRANS_M0; HWRITE = HWRITE_M0; end
            4'd1: begin HADDR = HADDR_M1; HTRANS = HTRANS_M1; HWRITE = HWRITE_M1; end
            4'd2: begin HADDR = HADDR_M2; HTRANS = HTRANS_M2; HWRITE = HWRITE_M2; end
            4'd3: begin HADDR = HADDR_M3; HTRANS = HTRANS_M3; HWRITE = HWRITE_M3; end
            default: begin 
                HADDR = 32'd0; HTRANS = 2'b00; HWRITE = 1'b0; // Trạng thái IDLE an toàn
            end
        endcase
    end

    // 2B. MUX DỮ LIỆU GHI (Sử dụng HMASTER_data đã bị trễ 1 nhịp)
    always @(*) begin
        case (HMASTER_data)
            4'd0: HWDATA = HWDATA_M0;
            4'd1: HWDATA = HWDATA_M1;
            4'd2: HWDATA = HWDATA_M2;
            4'd3: HWDATA = HWDATA_M3;
            default: HWDATA = 32'd0;
        endcase
    end

    // =========================================================================
    // 3. LUỒNG SLAVE-TO-MASTER (S2M MUX)
    // =========================================================================
    
    // MUX DỮ LIỆU ĐỌC & PHẢN HỒI (Sử dụng HSELx_data đã bị trễ 1 nhịp)
    always @(*) begin
        if (HSEL_S0_data) begin
            HRDATA = HRDATA_S0; HREADY = HREADYOUT_S0; HRESP = HRESP_S0;
        end else if (HSEL_S1_data) begin
            HRDATA = HRDATA_S1; HREADY = HREADYOUT_S1; HRESP = HRESP_S1;
        end else if (HSEL_S2_data) begin
            HRDATA = HRDATA_S2; HREADY = HREADYOUT_S2; HRESP = HRESP_S2;
        end else if (HSEL_S3_data) begin
            HRDATA = HRDATA_S3; HREADY = HREADYOUT_S3; HRESP = HRESP_S3;
        end else if (HSEL_DEFAULT_data) begin
            HRDATA = HRDATA_DEF; HREADY = HREADYOUT_DEF; HRESP = HRESP_DEF;
        end else begin
            // Trường hợp Fallback an toàn nếu có lỗi giải mã
            HRDATA = 32'd0; 
            HREADY = 1'b1;     // Ép HREADY = 1 để hệ thống không bị treo cứng
            HRESP  = 2'b01;    // Báo lỗi ERROR (2'b01) về cho Master
        end
    end

endmodule
