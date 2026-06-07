// Các tác vụ phát lệnh và chờ hoàn tất dùng chung.
task clear_cmds;
    begin
        cmd_start_m1 = 0; cmd_write_m1 = 0; cmd_lock_m1 = 0; cmd_addr_m1 = 0; cmd_wdata_m1 = 0;
        cmd_start_m2 = 0; cmd_write_m2 = 0; cmd_lock_m2 = 0; cmd_addr_m2 = 0; cmd_wdata_m2 = 0;
        cmd_start_m3 = 0; cmd_write_m3 = 0; cmd_lock_m3 = 0; cmd_addr_m3 = 0; cmd_wdata_m3 = 0;
        cmd_size_m1 = 3'b010; cmd_size_m2 = 3'b010; cmd_size_m3 = 3'b010;
        stall_req_s1 = 0; stall_req_s2 = 0;
    end
endtask

task reset_dut;
    begin
        clear_cmds();
        HRESETn = 1'b0;
        repeat (3) @(posedge HCLK);
        HRESETn = 1'b1;
        repeat (3) @(posedge HCLK);
        if (dbg_hmaster !== 2'd0)
            $fatal(1, "Bus không chuyển về bộ chủ mặc định sau khi đặt lại");
    end
endtask

task pulse_m1;
    input [31:0] addr;
    input [31:0] data;
    input        write;
    input        lock;
    begin
        pulse_m1_size(addr, data, write, lock, 3'b010);
    end
endtask

task pulse_m1_size;
    input [31:0] addr;
    input [31:0] data;
    input        write;
    input        lock;
    input [2:0]  size;
    begin
        @(posedge HCLK);
        cmd_addr_m1 <= addr; cmd_wdata_m1 <= data; cmd_write_m1 <= write;
        cmd_lock_m1 <= lock; cmd_size_m1 <= size; cmd_start_m1 <= 1'b1;
        @(posedge HCLK);
        cmd_start_m1 <= 1'b0;
    end
endtask

task pulse_m2;
    input [31:0] addr;
    input [31:0] data;
    input        write;
    input        lock;
    begin
        @(posedge HCLK);
        cmd_addr_m2 <= addr; cmd_wdata_m2 <= data; cmd_write_m2 <= write;
        cmd_lock_m2 <= lock; cmd_size_m2 <= 3'b010; cmd_start_m2 <= 1'b1;
        @(posedge HCLK);
        cmd_start_m2 <= 1'b0;
    end
endtask

task wait_done_or_error_m1;
    integer cycles;
    begin
        @(negedge HCLK);
        cycles = 0;
        while ((done_m1 || error_m1) && cycles < 10) begin @(posedge HCLK); cycles = cycles + 1; end
        while (!done_m1 && !error_m1 && cycles < 80) begin @(posedge HCLK); cycles = cycles + 1; end
        if (cycles == 80) $fatal(1, "M1 quá thời gian chờ tại %0t", $time);
    end
endtask

task wait_done_or_error_m2;
    integer cycles;
    begin
        @(negedge HCLK);
        cycles = 0;
        while ((done_m2 || error_m2) && cycles < 10) begin @(posedge HCLK); cycles = cycles + 1; end
        while (!done_m2 && !error_m2 && cycles < 80) begin @(posedge HCLK); cycles = cycles + 1; end
        if (cycles == 80) $fatal(1, "M2 quá thời gian chờ tại %0t", $time);
    end
endtask

task wait_done_or_error_m3;
    integer cycles;
    begin
        @(negedge HCLK);
        cycles = 0;
        while ((done_m3 || error_m3) && cycles < 10) begin @(posedge HCLK); cycles = cycles + 1; end
        while (!done_m3 && !error_m3 && cycles < 80) begin @(posedge HCLK); cycles = cycles + 1; end
        if (cycles == 80) $fatal(1, "M3 quá thời gian chờ tại %0t", $time);
    end
endtask

task expect_hready_low;
    integer cycles;
    integer seen_low;
    begin
        cycles = 0; seen_low = 0;
        while (cycles < 5) begin
            @(posedge HCLK);
            if (dbg_hready === 1'b0) seen_low = 1;
            cycles = cycles + 1;
        end
        if (!seen_low) $fatal(1, "Yêu cầu chờ của S1 không kéo HREADY xuống thấp");
    end
endtask

task expect_hmastlock_high;
    integer cycles;
    integer seen_lock;
    begin
        cycles = 0; seen_lock = 0;
        while (!done_m1 && !error_m1 && cycles < 40) begin
            @(posedge HCLK);
            if (dbg_hmastlock === 1'b1) seen_lock = 1;
            cycles = cycles + 1;
        end
        if (!seen_lock) $fatal(1, "Giao dịch khóa không đưa HMASTLOCK lên cao");
    end
endtask
