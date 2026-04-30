// ahb_defines.v
// AHB defines for vaaman-ahb-verilog implementation
// Compatible with AHB3-Lite spec

`ifndef AHB_DEFINES_V
`define AHB_DEFINES_V

// =============================================
// HTRANS — Transfer Type
// =============================================
`define AHB_HTRANS_IDLE   2'b00  // No transfer
`define AHB_HTRANS_BUSY   2'b01  // Busy (master not ready)
`define AHB_HTRANS_NONSEQ 2'b10  // Non-sequential (first or only)
`define AHB_HTRANS_SEQ    2'b11  // Sequential (burst)

// =============================================
// HBURST — Burst Type
// =============================================
`define AHB_HBURST_SINGLE 3'b000  // Single transfer
`define AHB_HBURST_INCR   3'b001  // Incrementing (undefined length)
`define AHB_HBURST_WRAP4  3'b010  // 4-beat wrapping (not supported)
`define AHB_HBURST_INCR4  3'b011  // 4-beat incrementing
`define AHB_HBURST_WRAP8  3'b100  // 8-beat wrapping (not supported)
`define AHB_HBURST_INCR8  3'b101  // 8-beat incrementing
`define AHB_HBURST_WRAP16 3'b110  // 16-beat wrapping (not supported)
`define AHB_HBURST_INCR16 3'b111  // 16-beat incrementing

// =============================================
// HSIZE — Transfer Size
// =============================================
`define AHB_HSIZE_BYTE    3'b000  // 8-bit
`define AHB_HSIZE_HALF    3'b001  // 16-bit
`define AHB_HSIZE_WORD    3'b010  // 32-bit (max supported)
`define AHB_HSIZE_DWORD   3'b011  // 64-bit  (not supported)
`define AHB_HSIZE_128     3'b100  // 128-bit (not supported)

// =============================================
// HRESP — Slave Response
// =============================================
`define AHB_HRESP_OKAY    1'b0   // Transfer OK (only response used)
`define AHB_HRESP_ERROR   1'b1   // Transfer Error (not used)

// =============================================
// HWRITE — Transfer Direction
// =============================================
`define AHB_HWRITE_READ   1'b0   // Read transfer
`define AHB_HWRITE_WRITE  1'b1   // Write transfer

// =============================================
// HPROT — Protection Control (optional)
// =============================================
`define AHB_HPROT_OPCODE       4'b0000  // Opcode fetch
`define AHB_HPROT_DATA         4'b0001  // Data access
`define AHB_HPROT_USER         4'b0000  // User access
`define AHB_HPROT_PRIVILEGED   4'b0010  // Privileged access
`define AHB_HPROT_NON_BUFFABLE 4'b0000  // Non-bufferable
`define AHB_HPROT_BUFFABLE     4'b0100  // Bufferable
`define AHB_HPROT_NON_CACHABLE 4'b0000  // Non-cacheable
`define AHB_HPROT_CACHABLE     4'b1000  // Cacheable

// =============================================
// Bus Width Parameters
// =============================================
`define AHB_DATA_WIDTH    32    // Data bus width (max supported)
`define AHB_ADDR_WIDTH    32    // Address bus width
`define AHB_HSIZE_MAX     3'b010 // Max transfer size = 32-bit

// =============================================
// HMASTLOCK
// =============================================
`define AHB_UNLOCKED  1'b0
`define AHB_LOCKED    1'b1

// =============================================
// HREADY
// =============================================
`define AHB_HREADY_NOT_READY  1'b0  // Slave extending transfer
`define AHB_HREADY_READY      1'b1  // Transfer complete

`endif // AHB_DEFINES_V
