// Kiểm tra phân xử khi ba bộ chủ yêu cầu bus đồng thời.
task test_arbitration;
    begin
        $display("[KIỂM THỬ] Phân xử nhiều bộ chủ");
        @(posedge HCLK);
        cmd_addr_m1 <= 32'h2000_0010; cmd_wdata_m1 <= 32'h1111_1111; cmd_write_m1 <= 1'b1; cmd_start_m1 <= 1'b1;
        cmd_addr_m2 <= 32'h4000_0014; cmd_wdata_m2 <= 32'h2222_2222; cmd_write_m2 <= 1'b1; cmd_start_m2 <= 1'b1;
        cmd_addr_m3 <= 32'h2000_0018; cmd_wdata_m3 <= 32'h3333_3333; cmd_write_m3 <= 1'b1; cmd_start_m3 <= 1'b1;
        @(posedge HCLK);
        cmd_start_m1 <= 1'b0; cmd_start_m2 <= 1'b0; cmd_start_m3 <= 1'b0;
        fork
            wait_done_or_error_m1();
            wait_done_or_error_m2();
            wait_done_or_error_m3();
        join

        pulse_m1(32'h2000_0010, 32'h0, 1'b0, 1'b0); wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'h1111_1111) $fatal(1, "Dữ liệu kiểm tra phân xử của M1 không khớp");
        pulse_m2(32'h4000_0014, 32'h0, 1'b0, 1'b0); wait_done_or_error_m2();
        if (!done_m2 || rdata_m2 !== 32'h2222_2222) $fatal(1, "Dữ liệu kiểm tra phân xử của M2 không khớp");
        pulse_m1(32'h2000_0018, 32'h0, 1'b0, 1'b0); wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'h3333_3333) $fatal(1, "Dữ liệu kiểm tra phân xử của M3 không khớp");
    end
endtask

// Kiểm tra quyền sở hữu bus trong giao dịch có khóa.
task test_locked_transfer;
    begin
        $display("[KIỂM THỬ] Giao dịch khóa");
        @(posedge HCLK);
        cmd_addr_m1 <= 32'h4000_0020; cmd_wdata_m1 <= 32'h9999_9999;
        cmd_write_m1 <= 1'b1; cmd_lock_m1 <= 1'b1; cmd_start_m1 <= 1'b1;
        @(posedge HCLK);
        cmd_start_m1 <= 1'b0;
        cmd_addr_m2 <= 32'h4000_0024; cmd_wdata_m2 <= 32'h8888_8888;
        cmd_write_m2 <= 1'b1; cmd_start_m2 <= 1'b1;
        @(posedge HCLK);
        cmd_start_m2 <= 1'b0;
        expect_hmastlock_high();
        wait_done_or_error_m1();
        cmd_lock_m1 <= 1'b0;
        wait_done_or_error_m2();
    end
endtask
