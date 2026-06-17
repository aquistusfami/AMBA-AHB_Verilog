`timescale 1ns / 1ps

// Testbench chính: Sinh clock HCLK 100MHz và luồng chạy toàn bộ kiểm thử (tests)
module ahb_tb;

    integer run_all_tests;
    reg HCLK;
    reg HRESETn;

    // Giao tiếp M1
    reg         cmd_start_m1, cmd_write_m1, cmd_lock_m1;
    reg  [2:0]  cmd_size_m1;
    reg  [31:0] cmd_addr_m1, cmd_wdata_m1;
    wire [31:0] rdata_m1;
    wire        done_m1, error_m1;

    // Giao tiếp M2
    reg         cmd_start_m2, cmd_write_m2, cmd_lock_m2;
    reg  [2:0]  cmd_size_m2;
    reg  [31:0] cmd_addr_m2, cmd_wdata_m2;
    wire [31:0] rdata_m2;
    wire        done_m2, error_m2;

    // Giao tiếp M3
    reg         cmd_start_m3, cmd_write_m3, cmd_lock_m3;
    reg  [2:0]  cmd_size_m3;
    reg  [31:0] cmd_addr_m3, cmd_wdata_m3;
    wire [31:0] rdata_m3;
    wire        done_m3, error_m3;

    // Ép chu kỳ chờ (Stall)
    reg stall_req_s1;
    reg stall_req_s2;

    // Tín hiệu debug giám sát Bus
    wire [1:0]  dbg_hmaster;
    wire [3:0]  dbg_hgrant;
    wire        dbg_hready;
    wire [1:0]  dbg_hresp;
    wire [31:0] dbg_haddr;
    wire [1:0]  dbg_htrans;
    wire        dbg_hmastlock;

    reg         monitor_valid;
    reg         prev_hready;
    reg  [31:0] prev_haddr;
    reg  [1:0]  prev_htrans;
    reg         prev_hwrite;
    reg  [2:0]  prev_hsize;
    reg  [2:0]  prev_hburst;
    reg  [31:0] prev_hwdata;
    reg         response_phase2_pending;
    reg  [1:0]  response_pending;

    // Khởi tạo hệ thống Bus AHB (DUT)
    ahb_top dut (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .cmd_start_m1(cmd_start_m1), .cmd_write_m1(cmd_write_m1), .cmd_lock_m1(cmd_lock_m1), .cmd_size_m1(cmd_size_m1),
        .cmd_addr_m1(cmd_addr_m1), .cmd_wdata_m1(cmd_wdata_m1),
        .rdata_m1(rdata_m1), .done_m1(done_m1), .error_m1(error_m1),
        .cmd_start_m2(cmd_start_m2), .cmd_write_m2(cmd_write_m2), .cmd_lock_m2(cmd_lock_m2), .cmd_size_m2(cmd_size_m2),
        .cmd_addr_m2(cmd_addr_m2), .cmd_wdata_m2(cmd_wdata_m2),
        .rdata_m2(rdata_m2), .done_m2(done_m2), .error_m2(error_m2),
        .cmd_start_m3(cmd_start_m3), .cmd_write_m3(cmd_write_m3), .cmd_lock_m3(cmd_lock_m3), .cmd_size_m3(cmd_size_m3),
        .cmd_addr_m3(cmd_addr_m3), .cmd_wdata_m3(cmd_wdata_m3),
        .rdata_m3(rdata_m3), .done_m3(done_m3), .error_m3(error_m3),
        .stall_req_s1(stall_req_s1), .stall_req_s2(stall_req_s2),
        .dbg_hmaster(dbg_hmaster), .dbg_hgrant(dbg_hgrant), .dbg_hready(dbg_hready),
        .dbg_hresp(dbg_hresp), .dbg_haddr(dbg_haddr), .dbg_htrans(dbg_htrans),
        .dbg_hmastlock(dbg_hmastlock)
    );

    // Tạo nguồn xung nhịp HCLK chu kỳ 10 ns (100 MHz)
    initial begin
        HCLK = 1'b0;
        forever #5 HCLK = ~HCLK;
    end

    // Nhúng các kịch bản kiểm thử và bộ phân tích giao thức
    `include "ahb_tb_monitor.v"            // Bộ tự động kiểm tra giao thức
    `include "ahb_tb_tasks.v"              // Các hàm pulse phát lệnh và wait đợi hoàn tất
    `include "tests/ahb_transfer_tests.v"   // Các kịch bản test ghi/đọc cơ bản và làn dữ liệu
    `include "tests/ahb_wait_error_tests.v" // Các kịch bản test chèn trễ và báo lỗi địa chỉ
    `include "tests/ahb_multimaster_tests.v"// Các kịch bản test đa bộ chủ và khóa bus (HLOCK)

    // Luồng thực thi mô phỏng chính
    initial begin
        // Ghi lại dạng sóng để hiển thị qua GTKWave
        $dumpfile("ahb_wave.vcd");
        $dumpvars(0, ahb_tb);

        // Đặt lại hệ thống về trạng thái ban đầu ổn định
        reset_dut();

        // Kiểm tra tham số dòng lệnh lúc chạy để lọc kịch bản kiểm thử (plusargs)
        run_all_tests = !$test$plusargs("TEST_TRANSFER") &&
                        !$test$plusargs("TEST_WAIT_ERROR") &&
                        !$test$plusargs("TEST_MULTIMASTER");

        // Chạy nhóm kịch bản kiểm thử 1
        if (run_all_tests || $test$plusargs("TEST_TRANSFER")) begin
            test_single_transfers();
            test_data_lanes();
            test_invalid_transfers();
        end

        // Chạy nhóm kịch bản kiểm thử 2
        if (run_all_tests || $test$plusargs("TEST_WAIT_ERROR")) begin
            test_wait_states();
            test_address_errors();
        end

        // Chạy nhóm kịch bản kiểm thử 3
        if (run_all_tests || $test$plusargs("TEST_MULTIMASTER")) begin
            test_arbitration();
            test_locked_transfer();
        end

        $display("=================================================");
        $display("       TẤT CẢ CÁC BÀI KIỂM THỬ ĐỀU ĐẠT CHUẨN      ");
        $display("=================================================");
        $finish;
    end

endmodule
