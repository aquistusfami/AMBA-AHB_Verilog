`timescale 1ns / 1ps

module ahb_arbiter #(
    parameter NUM_MASTERS = 4,
    parameter DEFAULT_MASTER = 4'd0
)(
    input  wire                   HCLK,
    input  wire                   HRESETn,

    // Tín hiệu yêu cầu từ Masters
    input  wire [NUM_MASTERS-1:0] HBUSREQ,
    input  wire [NUM_MASTERS-1:0] HLOCK,

    // Tín hiệu giám sát Bus
    input  wire [1:0]             HTRANS,
    input  wire [2:0]             HBURST,
    input  wire [1:0]             HRESP,
    input  wire                   HREADY,

    // Tín hiệu điều khiển xuất ra
    output reg  [NUM_MASTERS-1:0] HGRANT,
    output reg  [3:0]             HMASTER,
    output reg                    HMASTLOCK
);

    // --- Định nghĩa Localparam ---
    localparam TR_IDLE   = 2'b00;
    localparam TR_BUSY   = 2'b01;
    localparam TR_NONSEQ = 2'b10;
    localparam TR_SEQ    = 2'b11;

    localparam RESP_OKAY = 2'b00;

    // --- Thanh ghi trạng thái nội bộ ---
    reg  [3:0] last_master;
    reg  [3:0] beat_cnt;       // Bộ đếm nhịp cho Burst
    reg        burst_active;   // Cờ báo hiệu đang trong một gói Burst không thể ngắt

    // --- Biến Combinational ---
    wire [NUM_MASTERS-1:0] mask;
    wire [NUM_MASTERS-1:0] masked_req;
    wire [NUM_MASTERS-1:0] active_req;
    wire [NUM_MASTERS-1:0] next_grant_oh; 
    reg  [3:0]             next_master_id;
    
    wire error_or_retry;
    wire is_fixed_burst;
    wire is_burst_start;

    //--------------------------------------------------------------------------
    // 1. QUẢN LÝ BURST & NGOẠI LỆ (BEAT COUNTER & HRESP)
    //--------------------------------------------------------------------------
    assign error_or_retry = (HRESP != RESP_OKAY); 

    // Nhận diện ngay lập tức khoảnh khắc bắt đầu một gói Burst cố định
    assign is_fixed_burst = (HBURST == 3'b011 || HBURST == 3'b101 || HBURST == 3'b111);
    assign is_burst_start = (HTRANS == TR_NONSEQ) && is_fixed_burst;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            beat_cnt     <= 4'd0;
            burst_active <= 1'b0;
        end else if (error_or_retry) begin
            // Hủy Burst ngay lập tức nếu có lỗi
            beat_cnt     <= 4'd0;
            burst_active <= 1'b0;
        end else if (HREADY) begin
            if (is_burst_start) begin
                // Bắt đầu giao dịch: Nạp số nhịp CẦN GIỮ (Trừ đi nhịp NONSEQ và nhịp SEQ cuối)
                case (HBURST)
                    3'b011: begin beat_cnt <= 4'd2;  burst_active <= 1'b1; end // INCR4
                    3'b101: begin beat_cnt <= 4'd6;  burst_active <= 1'b1; end // INCR8
                    3'b111: begin beat_cnt <= 4'd14; burst_active <= 1'b1; end // INCR16
                    default:begin beat_cnt <= 4'd0;  burst_active <= 1'b0; end 
                endcase
            end else if (burst_active) begin
                // Chỉ trừ bộ đếm khi Master thực sự truyền tiếp (SEQ). 
                // Nếu Master chèn BUSY, bộ đếm không giảm.
                if (HTRANS == TR_SEQ) begin
                    if (beat_cnt > 4'd0) begin
                        beat_cnt <= beat_cnt - 1'b1;
                    end else begin
                        burst_active <= 1'b0; // Đã giữ đủ nhịp, mở khóa cho Arbiter
                    end
                end
            end
        end
    end

    //--------------------------------------------------------------------------
    // 2. LOGIC TỔ HỢP TÌM MASTER TIẾP THEO (ROUND-ROBIN)
    //--------------------------------------------------------------------------
    assign mask = ~((1 << (last_master + 1)) - 1);
    assign masked_req = HBUSREQ & mask;
    assign active_req = (|masked_req) ? masked_req : HBUSREQ;
    assign next_grant_oh = active_req & ~(active_req - 1);

    always @(*) begin
        case (next_grant_oh)
            4'b0001: next_master_id = 4'd0;
            4'b0010: next_master_id = 4'd1;
            4'b0100: next_master_id = 4'd2;
            4'b1000: next_master_id = 4'd3;
            default: next_master_id = DEFAULT_MASTER; 
        endcase
    end

    //--------------------------------------------------------------------------
    // 3. TÍNH TOÁN QUYẾT ĐỊNH CẤP QUYỀN (ARBITRATION DECISION)
    //--------------------------------------------------------------------------
    reg [3:0] final_next_master;

    always @(*) begin
        // Kiểm tra Lớp 1: Khóa cứng Bus 
        // Đã thêm is_burst_start để khóa ngay tại chu kỳ NONSEQ
        if (!error_or_retry && (HLOCK[HMASTER] || burst_active || is_burst_start || HTRANS == TR_BUSY)) begin
            final_next_master = HMASTER; // Giữ chặt Bus ở Master hiện tại
        end 
        // Kiểm tra Lớp 2 & 3: Round-Robin hoặc Default Master
        else begin
            if (|HBUSREQ) final_next_master = next_master_id;
            else          final_next_master = DEFAULT_MASTER;
        end
    end

    //--------------------------------------------------------------------------
    // 4. LOGIC TUẦN TỰ (PIPELINE & CHUYỂN GIAO QUYỀN)
    //--------------------------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            last_master <= DEFAULT_MASTER;
            HMASTER     <= DEFAULT_MASTER;
            HGRANT      <= (1 << DEFAULT_MASTER);
            HMASTLOCK   <= 1'b0;
        end else begin
            // FIX: HGRANT luôn được cập nhật độc lập, không bị chặn bởi HREADY
            // Giúp Master biết trước quyền để kịp đưa địa chỉ ra Bus
            if (!error_or_retry) begin
                HGRANT <= (1 << final_next_master);
            end else begin
                HGRANT <= (1 << DEFAULT_MASTER); // Thu hồi quyền lập tức nếu có lỗi
            end

            // HMASTER (Data Phase) CHỈ thay đổi ở nhịp HREADY == 1
            if (HREADY || error_or_retry) begin
                last_master <= final_next_master;
                HMASTER     <= final_next_master;
                HMASTLOCK   <= HLOCK[final_next_master];
            end
        end
    end

endmodule
