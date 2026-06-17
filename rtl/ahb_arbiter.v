`timescale 1ns/1ps

// Bộ phân xử Bus: Cấp quyền sử dụng bus cho các Master theo thứ tự xoay vòng (Round-Robin)
module ahb_arbiter #(
    parameter NUM_MASTERS    = 4,  // Số bộ chủ
    parameter DEFAULT_MASTER = 0   // Bộ chủ mặc định
)(
    input  wire                               HCLK,
    input  wire                               HRESETn,

    // Tín hiệu yêu cầu từ các Master
    input  wire [NUM_MASTERS-1:0]             HBUSREQ,     // Yêu cầu dùng Bus
    input  wire [NUM_MASTERS-1:0]             HLOCK,       // Yêu cầu khóa Bus

    // Tín hiệu báo sẵn sàng từ Slave
    input  wire                               HREADY,      // Bus sẵn sàng

    // Quyết định phân xử
    output reg  [NUM_MASTERS-1:0]             HGRANT,      // Cấp Bus cho Master tương ứng (One-hot)
    output reg  [$clog2(NUM_MASTERS)-1:0]     HMASTER,     // Chỉ số Master đang nắm giữ pha địa chỉ
    output reg                                HMASTLOCK    // Báo hiệu bus đang bị khóa
);

    localparam MASTER_W = $clog2(NUM_MASTERS);

    reg [MASTER_W-1:0]   current_master;  // Master đang sở hữu bus hiện tại
    reg [MASTER_W-1:0]   next_master;     // Master tiếp theo sẽ được nhận bus
    reg [MASTER_W-1:0]   last_granted;    // Master gần nhất được cấp bus (dùng để xoay vòng)

    integer i;
    reg [MASTER_W-1:0] temp_idx;
    reg                found;

    wire current_lock;
    wire hold_bus;

    // Xem Master hiện tại có đang khóa Bus không
    assign current_lock = (HMASTER < NUM_MASTERS) ? HLOCK[HMASTER] : 1'b0;

    // Giữ bus nếu Slave chưa xử lý xong (HREADY=0) hoặc Master hiện tại đang khóa bus
    assign hold_bus = !HREADY || current_lock;

    // Phân xử xoay vòng (Round-Robin) tìm Master tiếp theo có yêu cầu
    always @(*) begin
        next_master = current_master;
        found       = 1'b0;

        for (i = 1; i <= NUM_MASTERS; i = i + 1) begin
            temp_idx = last_granted + i[MASTER_W-1:0];
            if (temp_idx >= NUM_MASTERS)
                temp_idx = temp_idx - NUM_MASTERS[MASTER_W-1:0];

            // Cấp Bus cho Master đầu tiên tìm thấy có gửi yêu cầu (HBUSREQ)
            if (HBUSREQ[temp_idx] && !found) begin
                next_master = temp_idx;
                found       = 1'b1;
            end
        end

        // Nếu không Master nào yêu cầu, trả bus về Master mặc định
        if (!found)
            next_master = DEFAULT_MASTER[MASTER_W-1:0];
    end

    // Cập nhật Master hiện hành
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

    // Cấp tín hiệu HGRANT (One-hot)
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HGRANT <= ({{(NUM_MASTERS-1){1'b0}}, 1'b1} << DEFAULT_MASTER);
        end
        else begin
            if (!hold_bus)
                HGRANT <= ({{(NUM_MASTERS-1){1'b0}}, 1'b1} << next_master);
        end
    end

    // Đồng bộ HMASTER và HMASTLOCK với pha địa chỉ (chỉ cập nhật khi HREADY=1)
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HMASTER   <= DEFAULT_MASTER[MASTER_W-1:0];
            HMASTLOCK <= 1'b0;
        end
        else begin
            if (HREADY) begin
                HMASTER <= current_master;
                HMASTLOCK <= (current_master < NUM_MASTERS) ? HLOCK[current_master] : 1'b0;
            end
        end
    end

endmodule
