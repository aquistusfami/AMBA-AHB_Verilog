// =============================================================================
// Module : ahb_master.v
// Description : AHB-Lite Master với FSM điều khiển luồng tạo địa chỉ/dữ liệu
//               Tuân theo AMBA AHB Specification Rev 2.0 (ARM IHI0011A)
//
// FSM States:
//   IDLE      - Không có transfer, HTRANS = IDLE (2'b00)
//   ADDR      - Phase địa chỉ: broadcast HADDR, HWRITE, HSIZE, HBURST, HTRANS
//   DATA_WR   - Phase dữ liệu ghi: drive HWDATA, chờ HREADY
//   DATA_RD   - Phase dữ liệu đọc: đọc HRDATA khi HREADY HIGH
//   WAIT      - Slave chèn wait state (HREADY = LOW)
//   ERROR     - Slave trả về HRESP = ERROR
// =============================================================================

module ahb_master (
    // Clock & Reset
    input  wire        HCLK,        // Bus clock
    input  wire        HRESETn,     // Active-low synchronous reset

    // AHB Master Outputs (to bus)
    output reg  [31:0] HADDR,       // Address bus (32-bit)
    output reg  [1:0]  HTRANS,      // Transfer type: IDLE/BUSY/NONSEQ/SEQ
    output reg         HWRITE,      // 1=Write, 0=Read
    output reg  [2:0]  HSIZE,       // Transfer size: 000=Byte, 001=HW, 010=Word
    output reg  [2:0]  HBURST,      // Burst type
    output reg  [3:0]  HPROT,       // Protection control
    output reg  [31:0] HWDATA,      // Write data bus

    // AHB Master Inputs (from bus)
    input  wire [31:0] HRDATA,      // Read data bus
    input  wire        HREADY,      // 1=Transfer complete, 0=Wait state
    input  wire [1:0]  HRESP,       // Response: OKAY/ERROR/RETRY/SPLIT

    // Control Interface (từ logic bên ngoài điều khiển master)
    input  wire        start,       // Pulse để bắt đầu 1 transfer
    input  wire [31:0] addr_in,     // Địa chỉ muốn truy cập
    input  wire        write_in,    // 1=Write, 0=Read
    input  wire [31:0] wdata_in,    // Dữ liệu ghi
    input  wire [2:0]  size_in,     // Kích thước transfer

    // Status Outputs
    output reg  [31:0] rdata_out,   // Dữ liệu đọc về
    output reg         done,        // Transfer hoàn thành (1 cycle pulse)
    output reg         error_out    // Có lỗi từ slave
);

    // -------------------------------------------------------------------------
    // HTRANS encoding (Bảng 3-1, AMBA AHB Spec)
    // -------------------------------------------------------------------------
    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_BUSY   = 2'b01;
    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    // -------------------------------------------------------------------------
    // HRESP encoding (Bảng 3-5, AMBA AHB Spec)
    // -------------------------------------------------------------------------
    localparam HRESP_OKAY    = 2'b00;
    localparam HRESP_ERROR   = 2'b01;
    localparam HRESP_RETRY   = 2'b10;
    localparam HRESP_SPLIT   = 2'b11;

    // -------------------------------------------------------------------------
    // HBURST encoding (Bảng 3-2, AMBA AHB Spec)
    // -------------------------------------------------------------------------
    localparam HBURST_SINGLE = 3'b000;
    localparam HBURST_INCR   = 3'b001;

    // -------------------------------------------------------------------------
    // FSM State Encoding
    // -------------------------------------------------------------------------
    localparam [2:0]
        ST_IDLE    = 3'd0,
        ST_ADDR    = 3'd1,
        ST_DATA_WR = 3'd2,
        ST_DATA_RD = 3'd3,
        ST_WAIT    = 3'd4,
        ST_ERROR   = 3'd5;

    // -------------------------------------------------------------------------
    // Internal Registers
    // -------------------------------------------------------------------------
    reg [2:0]  state, next_state;
    reg [31:0] addr_lat;    // Địa chỉ chốt lại khi bắt đầu transfer
    reg        write_lat;   // Hướng transfer chốt lại
    reg [31:0] wdata_lat;   // Dữ liệu ghi chốt lại
    reg [2:0]  size_lat;    // Kích thước chốt lại
    reg        wait_prev;   // Phân biệt giai đoạn WAIT

    // -------------------------------------------------------------------------
    // Sequential: State Register
    // -------------------------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    // -------------------------------------------------------------------------
    // Sequential: Chốt control inputs khi bắt đầu transfer
    // -------------------------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_lat  <= 32'h0;
            write_lat <= 1'b0;
            wdata_lat <= 32'h0;
            size_lat  <= 3'b010; // Word
        end else if (start && state == ST_IDLE) begin
            addr_lat  <= addr_in;
            write_lat <= write_in;
            wdata_lat <= wdata_in;
            size_lat  <= size_in;
        end
    end

    // -------------------------------------------------------------------------
    // Combinational: Next-State Logic
    // -------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (start)
                    next_state = ST_ADDR;
            end

            ST_ADDR: begin
                // Phase địa chỉ — luôn tiếp tục sang phase dữ liệu ngay chu kỳ sau
                // (Theo AHB: address phase 1 cycle, data phase bắt đầu tiếp theo)
                if (write_lat)
                    next_state = ST_DATA_WR;
                else
                    next_state = ST_DATA_RD;
            end

            ST_DATA_WR: begin
                if (!HREADY)
                    next_state = ST_WAIT;
                else if (HRESP == HRESP_ERROR)
                    next_state = ST_ERROR;
                else if (HRESP == HRESP_OKAY)
                    next_state = ST_IDLE;
                else
                    next_state = ST_ADDR; // RETRY: thực hiện lại
            end

            ST_DATA_RD: begin
                if (!HREADY)
                    next_state = ST_WAIT;
                else if (HRESP == HRESP_ERROR)
                    next_state = ST_ERROR;
                else if (HRESP == HRESP_OKAY)
                    next_state = ST_IDLE;
                else
                    next_state = ST_ADDR; // RETRY
            end

            ST_WAIT: begin
                // Chờ HREADY HIGH từ slave
                if (HREADY) begin
                    if (HRESP == HRESP_ERROR)
                        next_state = ST_ERROR;
                    else if (write_lat)
                        next_state = ST_DATA_WR;
                    else
                        next_state = ST_DATA_RD;
                end
            end

            ST_ERROR: begin
                // Sau 1 cycle báo error, về IDLE
                next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // Sequential: Output Logic (Mealy/Moore combined)
    // -------------------------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HADDR     <= 32'h0;
            HTRANS    <= HTRANS_IDLE;
            HWRITE    <= 1'b0;
            HSIZE     <= 3'b010;
            HBURST    <= HBURST_SINGLE;
            HPROT     <= 4'b0011;       // Data, privileged
            HWDATA    <= 32'h0;
            rdata_out <= 32'h0;
            done      <= 1'b0;
            error_out <= 1'b0;
        end else begin
            // Defaults mỗi cycle
            done      <= 1'b0;
            error_out <= 1'b0;

            case (next_state)
                ST_IDLE: begin
                    HTRANS <= HTRANS_IDLE;
                    HADDR  <= 32'h0;
                    HWRITE <= 1'b0;
                end

                ST_ADDR: begin
                    // Broadcast address + control signals (pipelined: address phase)
                    HADDR  <= addr_lat;
                    HWRITE <= write_lat;
                    HSIZE  <= size_lat;
                    HBURST <= HBURST_SINGLE;
                    HPROT  <= 4'b0011;
                    HTRANS <= HTRANS_NONSEQ;
                end

                ST_DATA_WR: begin
                    // Data phase cho write: drive HWDATA
                    HWDATA <= wdata_lat;
                    HTRANS <= HTRANS_IDLE; // Single transfer — không có beat tiếp theo
                end

                ST_DATA_RD: begin
                    // Data phase cho read: sample HRDATA khi HREADY HIGH
                    HTRANS <= HTRANS_IDLE;
                    if (HREADY && HRESP == HRESP_OKAY) begin
                        rdata_out <= HRDATA;
                        done      <= 1'b1;
                    end
                end

                ST_WAIT: begin
                    // Giữ nguyên HWDATA trong wait state (AHB: master phải giữ data valid)
                    // HTRANS giữ nguyên, không thay đổi address/control
                end

                ST_ERROR: begin
                    error_out <= 1'b1;
                    HTRANS    <= HTRANS_IDLE;
                    $display("[AHB_MASTER] ERROR response from slave @ HADDR=0x%08h, t=%0t", HADDR, $time);
                end
            endcase

            // Hoàn thành write
            if (state == ST_DATA_WR && HREADY && HRESP == HRESP_OKAY)
                done <= 1'b1;
        end
    end

endmodule
