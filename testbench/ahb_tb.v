`timescale 1ns / 1ps

// Testbench tổng hợp, cho phép chạy toàn bộ hoặc từng nhóm kiểm thử.
module ahb_tb;
    integer run_all_tests;
    reg HCLK;
    reg HRESETn;

    reg         cmd_start_m1, cmd_write_m1, cmd_lock_m1;
    reg  [2:0]  cmd_size_m1;
    reg  [31:0] cmd_addr_m1, cmd_wdata_m1;
    wire [31:0] rdata_m1;
    wire        done_m1, error_m1;

    reg         cmd_start_m2, cmd_write_m2, cmd_lock_m2;
    reg  [2:0]  cmd_size_m2;
    reg  [31:0] cmd_addr_m2, cmd_wdata_m2;
    wire [31:0] rdata_m2;
    wire        done_m2, error_m2;

    reg         cmd_start_m3, cmd_write_m3, cmd_lock_m3;
    reg  [2:0]  cmd_size_m3;
    reg  [31:0] cmd_addr_m3, cmd_wdata_m3;
    wire [31:0] rdata_m3;
    wire        done_m3, error_m3;

    reg stall_req_s1;
    reg stall_req_s2;

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

    // Khối thiết kế được kiểm thử.
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

    // Tạo xung nhịp chu kỳ 10 ns.
    initial begin
        HCLK = 1'b0;
        forever #5 HCLK = ~HCLK;
    end

    // Ghép các khối giám sát, tiện ích và kịch bản kiểm thử.
    `include "ahb_tb_monitor.vh"
    `include "ahb_tb_tasks.vh"
    `include "tests/ahb_transfer_tests.vh"
    `include "tests/ahb_wait_error_tests.vh"
    `include "tests/ahb_multimaster_tests.vh"

    // Chọn nhóm kiểm thử bằng plusarg; mặc định chạy tất cả.
    initial begin
        $dumpfile("ahb_wave.vcd");
        $dumpvars(0, ahb_tb);

        reset_dut();
        run_all_tests = !$test$plusargs("TEST_TRANSFER") &&
                        !$test$plusargs("TEST_WAIT_ERROR") &&
                        !$test$plusargs("TEST_MULTIMASTER");

        if (run_all_tests || $test$plusargs("TEST_TRANSFER")) begin
            test_single_transfers();
            test_data_lanes();
            test_invalid_transfers();
        end

        if (run_all_tests || $test$plusargs("TEST_WAIT_ERROR")) begin
            test_wait_states();
            test_address_errors();
        end

        if (run_all_tests || $test$plusargs("TEST_MULTIMASTER")) begin
            test_arbitration();
            test_locked_transfer();
        end

        $display("TẤT CẢ KIỂM THỬ ĐỀU ĐẠT");
        $finish;
    end
endmodule
