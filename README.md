# AMBA AHB Verilog

Dự án mô phỏng bus **AMBA 2 AHB multi-master** bằng Verilog. Thiết kế gồm master, arbiter, decoder, mux, slave bộ nhớ và testbench tự kiểm tra.

Tài liệu tham chiếu: `IHI0011a.pdf` - AMBA Specification Rev 2.0.

## 1. Thông tin nhóm sinh viên

* Nguyễn Trần An Hưng - 202418911
* Hoàng Chí Kiệt - 202418929
* Lê Thanh Mai - 202418940
* Nguyễn Văn Thế - 202418988

## 2. Cấu trúc thư mục

```text
AMBA-AHB_Verilog/
├── rtl/
│   ├── ahb_arbiter.v   # Phân xử bus giữa các master
│   ├── ahb_decoder.v   # Giải mã địa chỉ slave
│   ├── ahb_defines.v   # Hằng số AHB
│   ├── ahb_master.v    # Master AHB
│   ├── ahb_mux.v       # Mux địa chỉ, dữ liệu và phản hồi
│   ├── ahb_slave.v     # Slave bộ nhớ và default slave
│   └── ahb_top.v       # Kết nối toàn hệ thống
├── testbench/
│   └── ahb_tb.v        # Testbench tự kiểm tra
├── docs/               # Spec và plan phát triển
├── IHI0011a.pdf        # Tài liệu AMBA tham chiếu
└── README.md
```

## 3. Mô hình thiết kế

Mô hình hiện tại gồm:

* 4 master, trong đó master 0 là master mặc định để park bus.
* Arbiter round-robin có hỗ trợ `HLOCK`, `HMASTLOCK`, `HGRANT`, `HMASTER`.
* Decoder chọn slave theo vùng địa chỉ.
* Mux trung tâm chọn address/control, write data và response.
* Slave bộ nhớ hỗ trợ byte, halfword, word.
* Default slave trả `ERROR` cho vùng địa chỉ chưa map.
* Hỗ trợ wait state qua `HREADY`.
* Hỗ trợ phản hồi `ERROR` hai chu kỳ theo AMBA 2 AHB.

## 4. Bản đồ địa chỉ

| Slave | Vùng địa chỉ | Mô tả |
| --- | --- | --- |
| S0 | `0x0000_0000` - `0x0FFF_FFFF` | ROM / boot |
| S1 | `0x2000_0000` - `0x2FFF_FFFF` | SRAM |
| S2 | `0x4000_0000` - `0x4FFF_FFFF` | AHB-APB |
| S3 | `0x6000_0000` - `0x9FFF_FFFF` | DDR ngoài |
| Default | Các vùng còn lại | Trả `ERROR` |

Mỗi `ahb_slave` trong mô phỏng dùng RAM nội bộ 1 KB, bắt đầu từ `BASE_ADDR` của slave đó.

## 5. Cách chạy mô phỏng

Yêu cầu có `iverilog` và `vvp`.

```sh
iverilog -g2012 -I rtl -o /tmp/ahb_tb.out \
  testbench/ahb_tb.v \
  rtl/ahb_arbiter.v \
  rtl/ahb_decoder.v \
  rtl/ahb_master.v \
  rtl/ahb_mux.v \
  rtl/ahb_slave.v \
  rtl/ahb_top.v

vvp /tmp/ahb_tb.out
```

Kết quả đúng:

```text
ALL TESTS PASSED
```

Testbench cũng tạo file sóng:

```text
ahb_wave.vcd
```

Mở bằng GTKWave:

```sh
gtkwave ahb_wave.vcd
```

## 6. Các tình huống kiểm thử

Testbench hiện kiểm tra các tình huống sau:

1. **Reset và bus idle**
   Kiểm tra bus park về master mặc định sau reset.

2. **Single write**
   Master 1 ghi `0xDEAD_BEEF` vào S1 tại `0x2000_0004`.

3. **Single read**
   Master 1 đọc lại `0x2000_0004` và kiểm tra dữ liệu đúng.

4. **Wait state**
   Ép S1 kéo `HREADY` xuống thấp, sau đó bỏ stall và kiểm tra transfer hoàn tất.

5. **Multi-master arbitration**
   Master 1, 2, 3 cùng yêu cầu bus. Arbiter phải cấp bus để cả ba transfer hoàn tất.

6. **Locked transfer**
   Master 1 khóa bus bằng `HLOCK`. Kiểm tra `HMASTLOCK` và thứ tự cấp bus.

7. **Invalid address trong vùng slave**
   Truy cập `0x2000_1000`, vượt quá RAM 1 KB của S1. S1 phải trả `ERROR`.

8. **Default slave**
   Truy cập `0x1000_0000`, là vùng chưa map. Default slave phải trả `ERROR`.

## 7. Tín hiệu nên xem trên waveform

Nhóm tín hiệu chung:

```text
HCLK
HRESETn
dut.dbg_hmaster
dut.dbg_hgrant
dut.dbg_hready
dut.dbg_hresp
dut.dbg_haddr
dut.dbg_htrans
dut.dbg_hmastlock
```

Nhóm command và trạng thái master:

```text
cmd_start_m1, cmd_write_m1, cmd_lock_m1, cmd_addr_m1, cmd_wdata_m1
cmd_start_m2, cmd_write_m2, cmd_lock_m2, cmd_addr_m2, cmd_wdata_m2
cmd_start_m3, cmd_write_m3, cmd_lock_m3, cmd_addr_m3, cmd_wdata_m3
done_m1, done_m2, done_m3
error_m1, error_m2, error_m3
rdata_m1, rdata_m2, rdata_m3
```

Nhóm bus nội bộ:

```text
dut.HBUSREQ
dut.HLOCK
dut.HGRANT
dut.HMASTER
dut.HMASTLOCK
dut.HADDR
dut.HWRITE
dut.HTRANS
dut.HWDATA
dut.HRDATA
dut.HREADY
dut.HRESP
```

Nhóm decoder và slave:

```text
dut.hsel_s0
dut.hsel_s1
dut.hsel_s2
dut.hsel_s3
dut.hsel_def
dut.hreadyout_s1
dut.hreadyout_s2
dut.u_slave1.addr_lat
dut.u_slave1.addr_valid
dut.u_slave1.err_phase2
dut.u_default_slave.trans_valid_lat
dut.u_default_slave.err_phase2
```

## 8. Kết quả mong đợi

Khi mô phỏng đúng:

* Giao dịch đọc/ghi trả dữ liệu đúng.
* `HREADY` xuống thấp khi slave chèn wait state.
* Arbiter cấp bus lần lượt cho nhiều master.
* `HMASTLOCK` lên cao trong locked transfer.
* Địa chỉ lỗi tạo `HRESP = ERROR`.
* Testbench kết thúc bằng `ALL TESTS PASSED`.
