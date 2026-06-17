`timescale 1ns / 1ps

// Bộ giải mã địa chỉ: Chọn bộ tớ (Slave) dựa trên địa chỉ HADDR
module ahb_decoder (
    input  wire [31:0] HADDR,        // Địa chỉ từ Master đang dùng Bus

    output wire        HSEL_S0,      // Chọn Slave 0
    output wire        HSEL_S1,      // Chọn Slave 1
    output wire        HSEL_S2,      // Chọn Slave 2
    output wire        HSEL_S3,      // Chọn Slave 3
    output wire        HSEL_DEFAULT  // Chọn Bộ tớ mặc định (khi địa chỉ không khớp ai)
);

    // Giải mã địa chỉ dựa trên 4 bit cao nhất HADDR[31:28]

    // Slave 0: Vùng địa chỉ 0x0000_0000 - 0x0FFF_FFFF
    assign HSEL_S0 = (HADDR[31:28] == 4'h0);

    // Slave 1: Vùng địa chỉ 0x2000_0000 - 0x2FFF_FFFF
    assign HSEL_S1 = (HADDR[31:28] == 4'h2);

    // Slave 2: Vùng địa chỉ 0x4000_0000 - 0x4FFF_FFFF
    assign HSEL_S2 = (HADDR[31:28] == 4'h4);

    // Slave 3: Vùng địa chỉ 0x6000_0000 - 0x9FFF_FFFF
    assign HSEL_S3 = (
        (HADDR[31:28] == 4'h6) || 
        (HADDR[31:28] == 4'h7) || 
        (HADDR[31:28] == 4'h8) || 
        (HADDR[31:28] == 4'h9)
    );

    // Chọn bộ tớ mặc định khi địa chỉ không thuộc bất kỳ bộ tớ nào ở trên
    assign HSEL_DEFAULT = !(HSEL_S0 || HSEL_S1 || HSEL_S2 || HSEL_S3);

endmodule
