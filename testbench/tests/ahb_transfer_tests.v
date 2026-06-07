// Kiểm tra ghi và đọc lại một từ dữ liệu.
task test_single_transfers;
    begin
        $display("[KIỂM THỬ] Đọc và ghi đơn");
        pulse_m1(32'h2000_0004, 32'hDEAD_BEEF, 1'b1, 1'b0);
        wait_done_or_error_m1();
        if (!done_m1 || error_m1) $fatal(1, "M1 ghi vào S1 thất bại");

        pulse_m1(32'h2000_0004, 32'h0, 1'b0, 1'b0);
        wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'hDEAD_BEEF)
            $fatal(1, "Dữ liệu M1 đọc lại không khớp, nhận được %08h", rdata_m1);
    end
endtask

// Kiểm tra ánh xạ làn dữ liệu cho byte và nửa từ.
task test_data_lanes;
    begin
        $display("[KIỂM THỬ] Các làn byte và nửa từ");
        pulse_m1(32'h2000_0020, 32'h1122_3344, 1'b1, 1'b0); wait_done_or_error_m1();
        pulse_m1_size(32'h2000_0021, 32'h0000_AA00, 1'b1, 1'b0, 3'b000); wait_done_or_error_m1();
        pulse_m1_size(32'h2000_0022, 32'hBBBB_0000, 1'b1, 1'b0, 3'b001); wait_done_or_error_m1();

        pulse_m1(32'h2000_0020, 32'h0, 1'b0, 1'b0); wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'hBBBB_AA44)
            $fatal(1, "Kết quả ghi byte/nửa từ không khớp, nhận được %08h", rdata_m1);

        pulse_m1_size(32'h2000_0021, 32'h0, 1'b0, 1'b0, 3'b000); wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'h0000_AA00)
            $fatal(1, "Làn dữ liệu đọc byte không khớp, nhận được %08h", rdata_m1);

        pulse_m1_size(32'h2000_0022, 32'h0, 1'b0, 1'b0, 3'b001); wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'hBBBB_0000)
            $fatal(1, "Làn dữ liệu đọc nửa từ không khớp, nhận được %08h", rdata_m1);
    end
endtask

// Kiểm tra ERROR với địa chỉ lệch hàng và kích thước không hợp lệ.
task test_invalid_transfers;
    begin
        $display("[KIỂM THỬ] Lỗi căn chỉnh và kích thước giao dịch");
        pulse_m1_size(32'h2000_0021, 32'h0, 1'b0, 1'b0, 3'b001); wait_done_or_error_m1();
        if (!error_m1 || done_m1) $fatal(1, "Giao dịch nửa từ không căn chỉnh không trả về ERROR");

        pulse_m1_size(32'h2000_0022, 32'h0, 1'b0, 1'b0, 3'b010); wait_done_or_error_m1();
        if (!error_m1 || done_m1) $fatal(1, "Giao dịch từ không căn chỉnh không trả về ERROR");

        pulse_m1_size(32'h2000_0020, 32'h0, 1'b0, 1'b0, 3'b011); wait_done_or_error_m1();
        if (!error_m1 || done_m1) $fatal(1, "Giao dịch rộng hơn bus 32 bit không trả về ERROR");
    end
endtask
