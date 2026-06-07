`timescale 1ns / 1ps

module ahb_decoder (
    input  wire [31:0] HADDR,

    output wire        HSEL_S0,
    output wire        HSEL_S1,
    output wire        HSEL_S2,
    output wire        HSEL_S3,
    output wire        HSEL_DEFAULT
);

// Giải mã địa chỉ theo bốn bit cao HADDR[31:28].
// Vùng chưa ánh xạ được chuyển tới bộ tớ mặc định.

// Vùng RAM mô phỏng S0: 0x0000_0000 - 0x0FFF_FFFF.
assign HSEL_S0 = (HADDR[31:28] == 4'h0);

// Vùng RAM mô phỏng S1: 0x2000_0000 - 0x2FFF_FFFF.
assign HSEL_S1 = (HADDR[31:28] == 4'h2);

// Vùng RAM mô phỏng S2: 0x4000_0000 - 0x4FFF_FFFF.
assign HSEL_S2 = (HADDR[31:28] == 4'h4);

// Vùng RAM mô phỏng S3: 0x6000_0000 - 0x9FFF_FFFF.
assign HSEL_S3 = (
    (HADDR[31:28] == 4'h6) || 
    (HADDR[31:28] == 4'h7) || 
    (HADDR[31:28] == 4'h8) || 
    (HADDR[31:28] == 4'h9)
);

// Bộ tớ mặc định cho vùng chưa ánh xạ.
assign HSEL_DEFAULT = !(HSEL_S0 || HSEL_S1 || HSEL_S2 || HSEL_S3);

endmodule
