// Kiểm tra chu kỳ chờ bình thường và lỗi khi chờ quá giới hạn.
task test_wait_states;
    begin
        $display("[KIỂM THỬ] Chu kỳ chờ và giới hạn thời gian chờ");
        @(posedge HCLK);
        stall_req_s1 <= 1'b1;
        pulse_m1(32'h2000_0008, 32'hBEEF_CAFE, 1'b1, 1'b0);
        expect_hready_low();
        stall_req_s1 <= 1'b0;
        wait_done_or_error_m1();
        if (!done_m1 || error_m1) $fatal(1, "Giao dịch ghi có chu kỳ chờ của M1 thất bại");

        @(posedge HCLK);
        stall_req_s1 <= 1'b1;
        pulse_m1(32'h2000_000C, 32'h0, 1'b0, 1'b0);
        wait_done_or_error_m1();
        stall_req_s1 <= 1'b0;
        if (!error_m1 || done_m1) $fatal(1, "Trạng thái chờ quá giới hạn không kết thúc bằng ERROR");
    end
endtask

// Kiểm tra ERROR từ RAM ngoài phạm vi và bộ tớ mặc định.
task test_address_errors;
    begin
        $display("[KIỂM THỬ] Lỗi địa chỉ của bộ tớ và bộ tớ mặc định");
        pulse_m1(32'h2000_1000, 32'h0, 1'b0, 1'b0);
        wait_done_or_error_m1();
        if (!error_m1 || done_m1) $fatal(1, "Địa chỉ S1 không hợp lệ không trả về ERROR");

        pulse_m1(32'h1000_0000, 32'h0, 1'b0, 1'b0);
        wait_done_or_error_m1();
        if (!error_m1 || done_m1) $fatal(1, "Địa chỉ của bộ tớ mặc định không trả về ERROR");
    end
endtask
