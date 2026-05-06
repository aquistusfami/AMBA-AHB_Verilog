`timescale 1ns / 1ps
`include "ahb_defines.v"

module ahb_tb;

    // =========================================================
    // 1. KHAI BÁO TÍN HIỆU (Signals Declaration)
    // =========================================================
    reg HCLK;
    reg HRESETn;

    // Tín hiệu giả lập từ các Master (Testbench đóng vai trò là Master)
    reg [3:0]  tb_HBUSREQ;
    reg [3:0]  tb_HLOCK;
    reg [31:0] tb_HADDR_M1, tb_HADDR_M2, tb_HADDR_M3;
    reg [1:0]  tb_HTRANS_M1, tb_HTRANS_M2, tb_HTRANS_M3;
    
    // Tín hiệu giả lập từ Slave (Để test độ trễ)
    reg tb_HREADY;

    // Tín hiệu quan sát từ hệ thống (Outputs từ Top module)
    wire [3:0]  sys_HGRANT;
    wire [3:0]  sys_HMASTER;
    wire [31:0] sys_HADDR;
    wire [1:0]  sys_HTRANS;

    // =========================================================
    // 2. KHỞI TẠO HỆ THỐNG (Instantiation)
    // =========================================================
    // Phần này chờ Thành viên 1 hoàn thành ahb_top.v để nối dây.
    /*
    ahb_top uut (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HBUSREQ(tb_HBUSREQ),
        .HLOCK(tb_HLOCK),
        // Nối các tín hiệu địa chỉ, dữ liệu của Master vào đây
        // ...
        .HREADY(tb_HREADY),
        .HGRANT(sys_HGRANT),
        .HMASTER(sys_HMASTER),
        .HADDR_OUT(sys_HADDR),
        .HTRANS_OUT(sys_HTRANS)
    );
    */

    // =========================================================
    // 3. TẠO XUNG NHỊP (Clock Generation)
    // =========================================================
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK; // Chu kỳ 10ns (100MHz)
    end

    // =========================================================
    // 4. KỊCH BẢN KIỂM THỬ (Test Scenarios)
    // =========================================================
    initial begin
        // Cấu hình xuất file dạng sóng
        $dumpfile("ahb_wave.vcd");
        $dumpvars(0, ahb_tb);

        // Đặt giá trị ban đầu
        tb_HBUSREQ = 4'b0000;
        tb_HLOCK   = 4'b0000;
        tb_HREADY  = 1'b1; // Slave luôn sẵn sàng ở trạng thái mặc định
        tb_HTRANS_M1 = `AHB_HTRANS_IDLE;
        tb_HTRANS_M2 = `AHB_HTRANS_IDLE;
        tb_HTRANS_M3 = `AHB_HTRANS_IDLE;

        // Reset hệ thống
        HRESETn = 0;
        #15 HRESETn = 1;
        $display("[%0t] System Reset Deactivated.", $time);

        // ---------------------------------------------------------
        // KỊCH BẢN 4: Bus Idle & Default Master
        // ---------------------------------------------------------
        $display("[%0t] SCENARIO 4: Bus Idle - Testing Default Master fallback.", $time);
        // Không có Master nào request, quan sát sys_HMASTER trỏ về 0
        #20;

        // ---------------------------------------------------------
        // KỊCH BẢN 1: Single Transfer - Zero Wait State (Master 1)
        // ---------------------------------------------------------
        $display("[%0t] SCENARIO 1: Single Transfer (M1 writes to S1).", $time);
        @(posedge HCLK);
        tb_HBUSREQ[1] = 1'b1; // M1 xin quyền
        
        @(posedge HCLK);
        // Nhận được quyền, bắt đầu Pha Địa chỉ (Address Phase)
        tb_HADDR_M1  = 32'h2000_0004; // Trỏ vào dải của Slave 1
        tb_HTRANS_M1 = `AHB_HTRANS_NONSEQ;
        
        @(posedge HCLK);
        // Chuyển sang Pha Dữ liệu (Data Phase), kết thúc xin quyền
        tb_HBUSREQ[1] = 1'b0; 
        tb_HTRANS_M1 = `AHB_HTRANS_IDLE;
        #20;

        // ---------------------------------------------------------
        // KỊCH BẢN 2: Round-Robin Arbitration
        // ---------------------------------------------------------
        $display("[%0t] SCENARIO 2: Round-Robin Arbitration (M1, M2, M3 assert requests).", $time);
        @(posedge HCLK);
        tb_HBUSREQ = 4'b1110; // Master 1, 2, 3 đồng thời yêu cầu

        // Giữ yêu cầu trong vài chu kỳ để Arbiter lần lượt cấp quyền
        #40;
        tb_HBUSREQ = 4'b0000; // Nhả yêu cầu
        #20;

        // ---------------------------------------------------------
        // KỊCH BẢN 3: Wait States & Pipelining
        // ---------------------------------------------------------
        $display("[%0t] SCENARIO 3: Pipelining Wait States (HREADY = 0).", $time);
        @(posedge HCLK);
        tb_HBUSREQ[1] = 1'b1; // M1 xin quyền
        
        @(posedge HCLK);
        tb_HADDR_M1 = 32'h4000_0000;
        tb_HTRANS_M1 = `AHB_HTRANS_NONSEQ;
        tb_HBUSREQ[2] = 1'b1; // M2 bỗng nhiên xin quyền ngay lúc này
        
        @(posedge HCLK);
        tb_HTRANS_M1 = `AHB_HTRANS_IDLE;
        tb_HADDR_M2 = 32'h2000_0008; 
        tb_HTRANS_M2 = `AHB_HTRANS_NONSEQ;
        
        // Slave bắt đầu kéo HREADY xuống 0 (Báo bận)
        tb_HREADY = 1'b0; 
        $display("[%0t] Slave asserts HREADY = 0 (Busy). System should freeze.", $time);
        
        #30; // Chờ 3 chu kỳ xung nhịp trong trạng thái bận
        
        tb_HREADY = 1'b1; // Slave đã xử lý xong
        $display("[%0t] Slave asserts HREADY = 1 (Ready). Pipelining resumes.", $time);
        tb_HBUSREQ[1] = 1'b0;
        tb_HBUSREQ[2] = 1'b0;
        tb_HTRANS_M2 = `AHB_HTRANS_IDLE;
        #20;

        // ---------------------------------------------------------
        // KỊCH BẢN 5: Locked Transfer (Ưu tiên tuyệt đối)
        // ---------------------------------------------------------
        $display("[%0t] SCENARIO 5: Locked Transfer.", $time);
        @(posedge HCLK);
        tb_HBUSREQ[1] = 1'b1;
        tb_HLOCK[1]   = 1'b1; // Master 1 khóa bus
        
        @(posedge HCLK);
        tb_HBUSREQ[2] = 1'b1;
        tb_HBUSREQ[3] = 1'b1; // M2 và M3 cố gắng xin bus
        
        // Dù M2 và M3 xin bus, HMASTER vẫn phải giữ nguyên là M1
        #40; 
        
        tb_HLOCK[1]   = 1'b0; // M1 nhả khóa
        tb_HBUSREQ[1] = 1'b0;
        $display("[%0t] Master 1 releases Lock.", $time);
        
        #30;
        tb_HBUSREQ = 4'b0000;

        $display("[%0t] ALL TESTS COMPLETED.", $time);
        $finish;
    end

endmodule
