// Các hằng số AHB được sử dụng trong thiết kế.

`ifndef AHB_DEFINES_V
`define AHB_DEFINES_V

// Kiểu truyền.
`define AHB_HTRANS_IDLE   2'b00  // Không truyền
`define AHB_HTRANS_NONSEQ 2'b10  // Truyền đầu

// Chỉ hỗ trợ giao dịch đơn.
`define AHB_HBURST_SINGLE 3'b000  // Một lần truyền

// Kích thước truyền trên bus dữ liệu 32 bit.
`define AHB_HSIZE_BYTE    3'b000  // 8 bit
`define AHB_HSIZE_HALF    3'b001  // 16 bit
`define AHB_HSIZE_WORD    3'b010  // 32 bit

// Phản hồi của bộ tớ.
`define AHB_HRESP_OKAY    2'b00  // Thành công
`define AHB_HRESP_ERROR   2'b01  // Lỗi

// Hướng truyền dữ liệu.
`define AHB_HWRITE_READ   1'b0   // Đọc
`define AHB_HWRITE_WRITE  1'b1   // Ghi

// Thuộc tính bảo vệ.
`define AHB_HPROT_OPCODE       4'b0000  // Lấy lệnh
`define AHB_HPROT_DATA         4'b0001  // Truy cập dữ liệu
`define AHB_HPROT_USER         4'b0000  // Chế độ người dùng
`define AHB_HPROT_PRIVILEGED   4'b0010  // Chế độ đặc quyền
`define AHB_HPROT_NON_BUFFABLE 4'b0000  // Không dùng bộ đệm
`define AHB_HPROT_BUFFABLE     4'b0100  // Có thể dùng bộ đệm
`define AHB_HPROT_NON_CACHABLE 4'b0000  // Không lưu vào bộ nhớ đệm
`define AHB_HPROT_CACHABLE     4'b1000  // Có thể lưu vào bộ nhớ đệm

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

`endif // Kết thúc khối bảo vệ định nghĩa
