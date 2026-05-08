`timescale 1ns/1ps

module ahb_arbiter #(
    parameter NUM_MASTERS    = 4,
    parameter DEFAULT_MASTER = 0
)(
    input  wire                         HCLK,
    input  wire                         HRESETn,

    // Master request signals
    input  wire [NUM_MASTERS-1:0]       HBUSREQ,
    input  wire [NUM_MASTERS-1:0]       HLOCK,

    // AHB-Lite bus monitor signals
    input  wire [15:0]                  HSPLIT, // Đã bổ sung cổng HSPLIT
    input  wire [1:0]                   HTRANS,
    input  wire [2:0]                   HBURST,
    input  wire [1:0]                   HRESP,
    input  wire                         HREADY,

    // Arbiter outputs
    output reg  [NUM_MASTERS-1:0]       HGRANT,
    output reg  [$clog2(NUM_MASTERS)-1:0] HMASTER,
    output reg                         HMASTLOCK
);

////////////////////////////////////////////////////////////
// AHB-Lite Transfer Types
////////////////////////////////////////////////////////////

localparam TR_IDLE   = 2'b00;
localparam TR_BUSY   = 2'b01;
localparam TR_NONSEQ = 2'b10;
localparam TR_SEQ    = 2'b11;

////////////////////////////////////////////////////////////
// AHB-Lite Responses
////////////////////////////////////////////////////////////

localparam RESP_OKAY = 2'b00;
localparam RESP_ERROR = 2'b01;

////////////////////////////////////////////////////////////
// Internal Parameters
////////////////////////////////////////////////////////////

localparam MASTER_W = $clog2(NUM_MASTERS);

////////////////////////////////////////////////////////////
// Internal Registers
////////////////////////////////////////////////////////////

reg [MASTER_W-1:0] current_master;
reg [MASTER_W-1:0] next_master;
reg [MASTER_W-1:0] last_granted;
reg [MASTER_W-1:0] addr_phase_master;

reg [4:0] beat_cnt;
reg       burst_active;

integer i;

reg [MASTER_W-1:0] temp_idx;
reg                 found;

////////////////////////////////////////////////////////////
// Current Transfer Info
////////////////////////////////////////////////////////////

wire current_lock;
wire transfer_valid;
wire fixed_burst;
wire burst_last;
wire error_response;
wire hold_bus;

////////////////////////////////////////////////////////////
// Current Lock Status
////////////////////////////////////////////////////////////

assign current_lock =
    (HMASTER < NUM_MASTERS) ?
    HLOCK[HMASTER] : 1'b0;

////////////////////////////////////////////////////////////
// Valid Transfer Detect
////////////////////////////////////////////////////////////

assign transfer_valid = HTRANS[1];

////////////////////////////////////////////////////////////
// Fixed-Length Burst Detect
////////////////////////////////////////////////////////////

assign fixed_burst =
       (HBURST == 3'b010)   // WRAP4
    || (HBURST == 3'b011)   // INCR4
    || (HBURST == 3'b100)   // WRAP8
    || (HBURST == 3'b101)   // INCR8
    || (HBURST == 3'b110)   // WRAP16
    || (HBURST == 3'b111);  // INCR16

////////////////////////////////////////////////////////////
// AHB-Lite ERROR response
////////////////////////////////////////////////////////////

// AHB-Lite ERROR completes only when HREADY = 1
assign error_response =
    HREADY && (HRESP == RESP_ERROR);

////////////////////////////////////////////////////////////
// Burst last beat detect
////////////////////////////////////////////////////////////

assign burst_last =
    (beat_cnt == 0);

////////////////////////////////////////////////////////////
// Hold arbitration conditions
////////////////////////////////////////////////////////////

assign hold_bus =
       current_lock
    || burst_active
    || (transfer_valid && !HREADY);

////////////////////////////////////////////////////////////
// ROUND-ROBIN ARBITRATION
////////////////////////////////////////////////////////////

always @(*) begin

    next_master = current_master;
    found       = 1'b0;

    for (i = 1; i <= NUM_MASTERS; i = i + 1) begin

        temp_idx = last_granted + i;

        if (temp_idx >= NUM_MASTERS)
            temp_idx = temp_idx - NUM_MASTERS;

        if (HBUSREQ[temp_idx] && !found) begin
            next_master = temp_idx;
            found       = 1'b1;
        end
    end

    // Parking to default master
    if (!found)
        next_master = DEFAULT_MASTER;

end

////////////////////////////////////////////////////////////
// BURST CONTROL
////////////////////////////////////////////////////////////

always @(posedge HCLK or negedge HRESETn) begin

    if (!HRESETn) begin

        burst_active <= 1'b0;
        beat_cnt     <= 5'd0;

    end
    else begin

        // Abort burst on ERROR response
        if (error_response) begin

            burst_active <= 1'b0;
            beat_cnt     <= 5'd0;

        end
        else if (HREADY) begin

            ////////////////////////////////////////////////////
            // Start fixed-length burst
            ////////////////////////////////////////////////////

            if ((HTRANS == TR_NONSEQ) && fixed_burst) begin

                burst_active <= 1'b1;

                case (HBURST)

                    // Remaining SEQ beats only

                    3'b010,
                    3'b011:
                        beat_cnt <= 5'd2;

                    3'b100,
                    3'b101:
                        beat_cnt <= 5'd6;

                    3'b110,
                    3'b111:
                        beat_cnt <= 5'd14;

                    default:
                        beat_cnt <= 5'd0;

                endcase
            end

            ////////////////////////////////////////////////////
            // Continue burst
            ////////////////////////////////////////////////////

            else if (burst_active && (HTRANS == TR_SEQ)) begin

                if (!burst_last) begin

                    beat_cnt <= beat_cnt - 1'b1;

                end
                else begin

                    burst_active <= 1'b0;

                end
            end
        end
    end
end

////////////////////////////////////////////////////////////
// ADDRESS PHASE ARBITRATION
////////////////////////////////////////////////////////////

always @(posedge HCLK or negedge HRESETn) begin

    if (!HRESETn) begin

        current_master    <= DEFAULT_MASTER;
        addr_phase_master <= DEFAULT_MASTER;
        last_granted      <= DEFAULT_MASTER;

    end
    else begin

        if (!hold_bus) begin

            current_master    <= next_master;
            addr_phase_master <= next_master;
            last_granted      <= next_master;

        end
    end
end

////////////////////////////////////////////////////////////
// HGRANT GENERATION
////////////////////////////////////////////////////////////

always @(posedge HCLK or negedge HRESETn) begin

    if (!HRESETn) begin

        // Đã sử dụng NUM_MASTERS để giới hạn độ rộng bit cho HGRANT
        HGRANT <= ( {{(NUM_MASTERS-1){1'b0}}, 1'b1} << DEFAULT_MASTER );

    end
    else begin

        if (!hold_bus) begin

            // Đã sử dụng NUM_MASTERS để giới hạn độ rộng bit cho HGRANT
            HGRANT <= ( {{(NUM_MASTERS-1){1'b0}}, 1'b1} << next_master );

        end
    end
end

////////////////////////////////////////////////////////////
// DATA PHASE MASTER PIPELINE
////////////////////////////////////////////////////////////

always @(posedge HCLK or negedge HRESETn) begin

    if (!HRESETn) begin

        HMASTER   <= DEFAULT_MASTER;
        HMASTLOCK <= 1'b0;

    end
    else begin

        // Update only when transfer advances
        if (HREADY) begin

            HMASTER <= addr_phase_master;

            if (addr_phase_master < NUM_MASTERS)
                HMASTLOCK <= HLOCK[addr_phase_master];
            else
                HMASTLOCK <= 1'b0;

        end
    end
end

endmodule
