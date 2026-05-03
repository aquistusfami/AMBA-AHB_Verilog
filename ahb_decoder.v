`timescale 1ns / 1ps

module ahb_decoder (
    // Tín hiệu địa chỉ từ Master đang giữ Bus (thông qua Arbiter/MUX)
    input  wire [31:0] HADDR,

    // Các tín hiệu chọn Slave (One-Hot)
    output reg         HSEL_S0,       // Chọn Slave 0: ROM / Boot Flash
    output reg         HSEL_S1,       // Chọn Slave 1: SRAM (Internal Data)
    output reg         HSEL_S2,       // Chọn Slave 2: AHB to APB Bridge (Ngoại vi)
    output reg         HSEL_S3,       // Chọn Slave 3: External Memory (DDR)
    output reg         HSEL_DEFAULT   // Chọn Default Slave (Bảo vệ hệ thống)
);

    // Mạch tổ hợp giải mã địa chỉ (Combinational Decoding Logic)
    always @(*) begin
        // 1. Khởi tạo tất cả về 0 ở đầu chu kỳ quét. 
        // ĐÂY LÀ NGUYÊN TẮC BẮT BUỘC ĐỂ TRÁNH SINH RA LATCH TRONG THIẾT KẾ IC!
        HSEL_S0      = 1'b0;
        HSEL_S1      = 1'b0;
        HSEL_S2      = 1'b0;
        HSEL_S3      = 1'b0;
        HSEL_DEFAULT = 1'b0;

        // 2. Trích xuất 4 bit MSB (HADDR[31:28]) để định tuyến
        case (HADDR[31:28])
            4'h0: begin
                // Dải 0x0000_0000 đến 0x0FFF_FFFF
                HSEL_S0 = 1'b1; 
            end
            
            4'h2: begin
                // Dải 0x2000_0000 đến 0x2FFF_FFFF
                HSEL_S1 = 1'b1; 
            end
            
            4'h4: begin
                // Dải 0x4000_0000 đến 0x4FFF_FFFF
                HSEL_S2 = 1'b1; 
            end
            
            // Dải 0x6000_0000 đến 0x9FFF_FFFF (Dung lượng 1GB cần 4 dải 256MB ghép lại)
            4'h6, 4'h7, 4'h8, 4'h9: begin
                HSEL_S3 = 1'b1; 
            end
            
            // 3. Cơ chế Fallback: Nếu trỏ vào vùng trống, lập tức gọi Default Slave
            default: begin
                HSEL_DEFAULT = 1'b1; 
            end
        endcase
    end

endmodule
