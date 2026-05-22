// Định nghĩa hằng số AHB.

`ifndef AHB_DEFINES_V
`define AHB_DEFINES_V

// Kiểu truyền.
`define AHB_HTRANS_IDLE   2'b00  // Không truyền
`define AHB_HTRANS_BUSY   2'b01  // Master bận
`define AHB_HTRANS_NONSEQ 2'b10  // Truyền đầu
`define AHB_HTRANS_SEQ    2'b11  // Truyền tiếp theo

// Kiểu burst.
`define AHB_HBURST_SINGLE 3'b000  // Một lần truyền
`define AHB_HBURST_INCR   3'b001  // Tăng địa chỉ
`define AHB_HBURST_WRAP4  3'b010  // Vòng 4 beat
`define AHB_HBURST_INCR4  3'b011  // Tăng 4 beat
`define AHB_HBURST_WRAP8  3'b100  // Vòng 8 beat
`define AHB_HBURST_INCR8  3'b101  // Tăng 8 beat
`define AHB_HBURST_WRAP16 3'b110  // Vòng 16 beat
`define AHB_HBURST_INCR16 3'b111  // Tăng 16 beat

// Kích thước truyền.
`define AHB_HSIZE_BYTE    3'b000  // 8 bit
`define AHB_HSIZE_HALF    3'b001  // 16 bit
`define AHB_HSIZE_WORD    3'b010  // 32 bit
`define AHB_HSIZE_DWORD   3'b011  // 64 bit
`define AHB_HSIZE_128     3'b100  // 128 bit

// Phản hồi slave.
`define AHB_HRESP_OKAY    1'b0   // Thành công
`define AHB_HRESP_ERROR   1'b1   // Lỗi

// Hướng truyền dữ liệu.
`define AHB_HWRITE_READ   1'b0   // Đọc
`define AHB_HWRITE_WRITE  1'b1   // Ghi

// Thuộc tính bảo vệ.
`define AHB_HPROT_OPCODE       4'b0000  // Lấy lệnh
`define AHB_HPROT_DATA         4'b0001  // Truy cập dữ liệu
`define AHB_HPROT_USER         4'b0000  // Chế độ user
`define AHB_HPROT_PRIVILEGED   4'b0010  // Chế độ đặc quyền
`define AHB_HPROT_NON_BUFFABLE 4'b0000  // Không buffer
`define AHB_HPROT_BUFFABLE     4'b0100  // Có buffer
`define AHB_HPROT_NON_CACHABLE 4'b0000  // Không cache
`define AHB_HPROT_CACHABLE     4'b1000  // Có cache

// Độ rộng bus.
`define AHB_DATA_WIDTH    32    // Bus dữ liệu
`define AHB_ADDR_WIDTH    32    // Bus địa chỉ
`define AHB_HSIZE_MAX     3'b010 // Lần truyền lớn nhất

// Trạng thái khóa bus.
`define AHB_UNLOCKED  1'b0
`define AHB_LOCKED    1'b1

// Trạng thái sẵn sàng.
`define AHB_HREADY_NOT_READY  1'b0  // Đang chờ
`define AHB_HREADY_READY      1'b1  // Hoàn tất

`endif // Kết thúc guard
