// Định nghĩa các hằng số tiêu chuẩn cho Bus AHB 2.0

`ifndef AHB_DEFINES_V
`define AHB_DEFINES_V

// Kiểu truyền (HTRANS)
`define AHB_HTRANS_IDLE   2'b00  // Bus rỗi, không truyền dữ liệu
`define AHB_HTRANS_NONSEQ 2'b10  // Giao dịch đơn lẻ hoặc giao dịch đầu tiên

// Kiểu chuỗi truyền (HBURST) - Dự án này chỉ hỗ trợ giao dịch đơn
`define AHB_HBURST_SINGLE 3'b000  // Truyền một lần duy nhất

// Kích thước truyền dữ liệu (HSIZE)
`define AHB_HSIZE_BYTE    3'b000  // 8 bit (Byte)
`define AHB_HSIZE_HALF    3'b001  // 16 bit (Nửa từ)
`define AHB_HSIZE_WORD    3'b010  // 32 bit (Một từ)
`define AHB_HSIZE_MAX     3'b010  // Kích thước tối đa được hỗ trợ (32 bit)

// Phản hồi từ bộ tớ (HRESP)
`define AHB_HRESP_OKAY    2'b00  // Thành công hoặc bình thường
`define AHB_HRESP_ERROR   2'b01  // Báo lỗi (địa chỉ sai, lệch hàng...)

// Hướng truyền dữ liệu (HWRITE)
`define AHB_HWRITE_READ   1'b0   // Đọc dữ liệu từ Slave
`define AHB_HWRITE_WRITE  1'b1   // Ghi dữ liệu xuống Slave

// Các hằng số bảo vệ (HPROT)
`define AHB_HPROT_OPCODE       4'b0000
`define AHB_HPROT_DATA         4'b0001
`define AHB_HPROT_USER         4'b0000
`define AHB_HPROT_PRIVILEGED   4'b0010
`define AHB_HPROT_NON_BUFFABLE 4'b0000
`define AHB_HPROT_BUFFABLE     4'b0100
`define AHB_HPROT_NON_CACHABLE 4'b0000
`define AHB_HPROT_CACHABLE     4'b1000

// Độ rộng Bus địa chỉ và dữ liệu
`define AHB_DATA_WIDTH    32
`define AHB_ADDR_WIDTH    32

// Trạng thái khóa Bus (HLOCK)
`define AHB_UNLOCKED  1'b0  // Không khóa bus
`define AHB_LOCKED    1'b1  // Khóa bus (không cho Master khác chen vào)

// Trạng thái sẵn sàng (HREADY)
`define AHB_HREADY_NOT_READY  1'b0  // Chưa sẵn sàng (bắt bus chờ)
`define AHB_HREADY_READY      1'b1  // Đã sẵn sàng (hoàn tất giao dịch)

`endif // AHB_DEFINES_V
