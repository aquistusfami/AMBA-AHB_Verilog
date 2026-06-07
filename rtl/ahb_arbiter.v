`timescale 1ns/1ps
// Bộ phân xử cấp bus theo vòng tròn và giữ quyền khi bus chờ hoặc bị khóa.
module ahb_arbiter #(
    parameter NUM_MASTERS    = 4,
    parameter DEFAULT_MASTER = 0
)(
    input  wire                               HCLK,
    input  wire                               HRESETn,

    // Tín hiệu yêu cầu từ bộ chủ.
    input  wire [NUM_MASTERS-1:0]             HBUSREQ,
    input  wire [NUM_MASTERS-1:0]             HLOCK,

    // Tín hiệu hoàn tất giao dịch hiện tại.
    input  wire                               HREADY,

    // Tín hiệu cấp bus.
    output reg  [NUM_MASTERS-1:0]             HGRANT,
    output reg  [$clog2(NUM_MASTERS)-1:0]     HMASTER,
    output reg                                HMASTLOCK
);

// Tham số nội bộ.

localparam MASTER_W = $clog2(NUM_MASTERS);

// Thanh ghi nội bộ.

reg [MASTER_W-1:0]   current_master;
reg [MASTER_W-1:0]   next_master;
reg [MASTER_W-1:0]   last_granted;

integer i;

reg [MASTER_W-1:0] temp_idx;
reg                found;

// Tín hiệu tổ hợp.

wire current_lock;
wire hold_bus;

// Trạng thái khóa của bộ chủ hiện tại.
assign current_lock =
    (HMASTER < NUM_MASTERS) ? HLOCK[HMASTER] : 1'b0;

// Giữ quyền sở hữu bus khi giao dịch đang chờ hoặc bộ chủ đang khóa bus.
assign hold_bus = !HREADY || current_lock;

always @(*) begin

    next_master = current_master;
    found       = 1'b0;

    for (i = 1; i <= NUM_MASTERS; i = i + 1) begin

        temp_idx = last_granted + i[MASTER_W-1:0];

        if (temp_idx >= NUM_MASTERS)
            temp_idx = temp_idx - NUM_MASTERS[MASTER_W-1:0];

        // Cấp bus cho bộ chủ đang yêu cầu theo thứ tự vòng tròn.
        if (HBUSREQ[temp_idx] && !found) begin
            next_master = temp_idx;
            found       = 1'b1;
        end
    end

    // Không có yêu cầu thì chuyển bus về bộ chủ mặc định.
    if (!found)
        next_master = DEFAULT_MASTER[MASTER_W-1:0];

end

// Cập nhật bộ chủ hiện tại sau khi giao dịch trước hoàn tất.
always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        current_master <= DEFAULT_MASTER[MASTER_W-1:0];
        last_granted   <= DEFAULT_MASTER[MASTER_W-1:0];
    end
    else begin
        if (!hold_bus) begin
            current_master <= next_master;
            last_granted   <= next_master;
        end
    end
end

// Phát tín hiệu cấp bus dạng one-hot.
always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        HGRANT <= ({{(NUM_MASTERS-1){1'b0}}, 1'b1} << DEFAULT_MASTER);
    end
    else begin
        if (!hold_bus)
            HGRANT <= ({{(NUM_MASTERS-1){1'b0}}, 1'b1} << next_master);
    end
end

// Căn chỉnh HMASTER và HMASTLOCK với pha địa chỉ.
always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        HMASTER   <= DEFAULT_MASTER[MASTER_W-1:0];
        HMASTLOCK <= 1'b0;
    end
    else begin
        if (HREADY) begin
            HMASTER <= current_master;
            HMASTLOCK <= (current_master < NUM_MASTERS) ?
                          HLOCK[current_master] : 1'b0;
        end
    end
end

endmodule
