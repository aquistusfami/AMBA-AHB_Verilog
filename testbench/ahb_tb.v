`timescale 1ns / 1ps

module ahb_tb;
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

    initial begin
        HCLK = 1'b0;
        forever #5 HCLK = ~HCLK;
    end

    task clear_cmds;
        begin
            cmd_start_m1 = 0; cmd_write_m1 = 0; cmd_lock_m1 = 0; cmd_addr_m1 = 0; cmd_wdata_m1 = 0;
            cmd_start_m2 = 0; cmd_write_m2 = 0; cmd_lock_m2 = 0; cmd_addr_m2 = 0; cmd_wdata_m2 = 0;
            cmd_start_m3 = 0; cmd_write_m3 = 0; cmd_lock_m3 = 0; cmd_addr_m3 = 0; cmd_wdata_m3 = 0;
            cmd_size_m1 = 3'b010; cmd_size_m2 = 3'b010; cmd_size_m3 = 3'b010;
            stall_req_s1 = 0; stall_req_s2 = 0;
        end
    endtask

    task pulse_m1;
        input [31:0] addr;
        input [31:0] data;
        input        write;
        input        lock;
        begin
            @(posedge HCLK);
            cmd_addr_m1  <= addr;
            cmd_wdata_m1 <= data;
            cmd_write_m1 <= write;
            cmd_lock_m1  <= lock;
            cmd_size_m1  <= 3'b010;
            cmd_start_m1 <= 1'b1;
            @(posedge HCLK);
            cmd_start_m1 <= 1'b0;
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
            cmd_addr_m1  <= addr;
            cmd_wdata_m1 <= data;
            cmd_write_m1 <= write;
            cmd_lock_m1  <= lock;
            cmd_size_m1  <= size;
            cmd_start_m1 <= 1'b1;
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
            cmd_addr_m2  <= addr;
            cmd_wdata_m2 <= data;
            cmd_write_m2 <= write;
            cmd_lock_m2  <= lock;
            cmd_size_m2  <= 3'b010;
            cmd_start_m2 <= 1'b1;
            @(posedge HCLK);
            cmd_start_m2 <= 1'b0;
        end
    endtask

    task wait_done_or_error_m1;
        integer cycles;
        begin
            @(posedge HCLK);
            cycles = 0;
            while (!done_m1 && !error_m1 && cycles < 80) begin
                @(posedge HCLK);
                cycles = cycles + 1;
            end
            if (cycles == 80)
                $fatal(1, "M1 timeout at %0t", $time);
        end
    endtask

    task wait_done_or_error_m2;
        integer cycles;
        begin
            @(posedge HCLK);
            cycles = 0;
            while (!done_m2 && !error_m2 && cycles < 80) begin
                @(posedge HCLK);
                cycles = cycles + 1;
            end
            if (cycles == 80)
                $fatal(1, "M2 timeout at %0t", $time);
        end
    endtask

    task wait_done_or_error_m3;
        integer cycles;
        begin
            @(posedge HCLK);
            cycles = 0;
            while (!done_m3 && !error_m3 && cycles < 80) begin
                @(posedge HCLK);
                cycles = cycles + 1;
            end
            if (cycles == 80)
                $fatal(1, "M3 timeout at %0t", $time);
        end
    endtask

    task expect_hready_low;
        integer cycles;
        integer seen_low;
        begin
            cycles = 0;
            seen_low = 0;
            while (cycles < 30) begin
                @(posedge HCLK);
                if (dbg_hready === 1'b0)
                    seen_low = 1;
                cycles = cycles + 1;
            end
            if (!seen_low)
                $fatal(1, "S1 stall did not lower HREADY");
        end
    endtask

    task expect_hmastlock_high;
        integer cycles;
        integer seen_lock;
        begin
            cycles = 0;
            seen_lock = 0;
            while (!done_m1 && !error_m1 && cycles < 40) begin
                @(posedge HCLK);
                if (dbg_hmastlock === 1'b1)
                    seen_lock = 1;
                cycles = cycles + 1;
            end
            if (!seen_lock)
                $fatal(1, "Locked transfer did not assert HMASTLOCK");
        end
    endtask

    initial begin
        $dumpfile("ahb_wave.vcd");
        $dumpvars(0, ahb_tb);

        clear_cmds();
        HRESETn = 1'b0;
        repeat (3) @(posedge HCLK);
        HRESETn = 1'b1;
        repeat (3) @(posedge HCLK);

        if (dbg_hmaster !== 2'd0)
            $fatal(1, "Bus did not park on default master after reset");

        pulse_m1(32'h2000_0004, 32'hDEAD_BEEF, 1'b1, 1'b0);
        wait_done_or_error_m1();
        if (!done_m1 || error_m1)
            $fatal(1, "M1 write to S1 failed");

        pulse_m1(32'h2000_0004, 32'h0, 1'b0, 1'b0);
        wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'hDEAD_BEEF)
            $fatal(1, "M1 readback mismatch: got %08h", rdata_m1);

        pulse_m1(32'h2000_0020, 32'h1122_3344, 1'b1, 1'b0);
        wait_done_or_error_m1();
        pulse_m1_size(32'h2000_0021, 32'h0000_AA00, 1'b1, 1'b0, 3'b000);
        wait_done_or_error_m1();
        pulse_m1_size(32'h2000_0022, 32'hBBBB_0000, 1'b1, 1'b0, 3'b001);
        wait_done_or_error_m1();
        pulse_m1(32'h2000_0020, 32'h0, 1'b0, 1'b0);
        wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'hBBBB_AA44)
            $fatal(1, "Byte/halfword write mismatch: got %08h", rdata_m1);
        pulse_m1_size(32'h2000_0021, 32'h0, 1'b0, 1'b0, 3'b000);
        wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'h0000_AA00)
            $fatal(1, "Byte read lane mismatch: got %08h", rdata_m1);
        pulse_m1_size(32'h2000_0022, 32'h0, 1'b0, 1'b0, 3'b001);
        wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'hBBBB_0000)
            $fatal(1, "Halfword read lane mismatch: got %08h", rdata_m1);

        @(posedge HCLK);
        stall_req_s1 <= 1'b1;
        pulse_m1(32'h2000_0008, 32'hBEEF_CAFE, 1'b1, 1'b0);
        expect_hready_low();
        stall_req_s1 <= 1'b0;
        wait_done_or_error_m1();
        if (!done_m1 || error_m1)
            $fatal(1, "M1 wait-state write failed");

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
        pulse_m1(32'h2000_0010, 32'h0, 1'b0, 1'b0);
        wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'h1111_1111)
            $fatal(1, "M1 arbitration writeback mismatch: got %08h", rdata_m1);
        pulse_m2(32'h4000_0014, 32'h0, 1'b0, 1'b0);
        wait_done_or_error_m2();
        if (!done_m2 || rdata_m2 !== 32'h2222_2222)
            $fatal(1, "M2 arbitration writeback mismatch: got %08h", rdata_m2);
        pulse_m1(32'h2000_0018, 32'h0, 1'b0, 1'b0);
        wait_done_or_error_m1();
        if (!done_m1 || rdata_m1 !== 32'h3333_3333)
            $fatal(1, "M3 arbitration writeback mismatch: got %08h", rdata_m1);

        @(posedge HCLK);
        cmd_addr_m1 <= 32'h4000_0020; cmd_wdata_m1 <= 32'h9999_9999; cmd_write_m1 <= 1'b1; cmd_lock_m1 <= 1'b1; cmd_start_m1 <= 1'b1;
        @(posedge HCLK);
        cmd_start_m1 <= 1'b0;
        cmd_addr_m2 <= 32'h4000_0024; cmd_wdata_m2 <= 32'h8888_8888; cmd_write_m2 <= 1'b1; cmd_start_m2 <= 1'b1;
        @(posedge HCLK);
        cmd_start_m2 <= 1'b0;
        expect_hmastlock_high();
        wait_done_or_error_m1();
        cmd_lock_m1 <= 1'b0;
        wait_done_or_error_m2();

        pulse_m1(32'h2000_1000, 32'h0, 1'b0, 1'b0);
        begin
            integer cycles;
            @(posedge HCLK);
            cycles = 0;
            while (!error_m1 && cycles < 80) begin
                @(posedge HCLK);
                cycles = cycles + 1;
            end
            if (cycles == 80)
                $fatal(1, "Invalid S1 address did not return ERROR");
        end

        pulse_m1(32'h1000_0000, 32'h0, 1'b0, 1'b0);
        begin
            integer cycles;
            @(posedge HCLK);
            cycles = 0;
            while (!error_m1 && cycles < 80) begin
                @(posedge HCLK);
                cycles = cycles + 1;
            end
            if (cycles == 80)
                $fatal(1, "Default slave address did not return ERROR");
        end

        $display("ALL TESTS PASSED");
        $finish;
    end
endmodule
