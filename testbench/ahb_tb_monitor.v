// Bộ giám sát tự động: Kiểm tra xem các tín hiệu trên bus có vi phạm giao thức AHB không
always @(negedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        monitor_valid           <= 1'b0;
        prev_hready             <= 1'b1;
        prev_haddr              <= 32'h0;
        prev_htrans             <= 2'b00;
        prev_hwrite             <= 1'b0;
        prev_hsize              <= 3'b000;
        prev_hburst             <= 3'b000;
        prev_hwdata             <= 32'h0;
        response_phase2_pending <= 1'b0;
        response_pending        <= 2'b00;
    end else begin
        // RÀNG BUỘC 1: Khi HREADY = 0 (bus bận), các tín hiệu điều khiển và địa chỉ của Master không được phép thay đổi
        if (monitor_valid && !prev_hready && !dbg_hready) begin
            if ((dbg_haddr !== prev_haddr) || (dbg_htrans !== prev_htrans) ||
                (dut.HWRITE !== prev_hwrite) || (dut.HSIZE !== prev_hsize) ||
                (dut.HBURST !== prev_hburst) || (dut.HWDATA !== prev_hwdata))
                $fatal(1, "LỖI GIAO THỨC: Tín hiệu AHB thay đổi khi HREADY đang ở mức thấp tại %0t", $time);
        end

        // RÀNG BUỘC 2: Phản hồi ERROR bắt buộc phải kéo dài đúng 2 chu kỳ clock (chu kỳ 2 có HREADY = 1)
        if (response_phase2_pending) begin
            if ((dbg_hready !== 1'b1) || (dbg_hresp !== response_pending))
                $fatal(1, "LỖI GIAO THỨC: Phản hồi ERROR không hoàn tất ở chu kỳ thứ hai tại %0t", $time);
            response_phase2_pending <= 1'b0;
        end else if ((dbg_hresp !== 2'b00) && (dbg_hready === 1'b0)) begin
            response_phase2_pending <= 1'b1;
            response_pending        <= dbg_hresp;
        end

        // RÀNG BUỘC 3: Khi bus đang bị khóa (HMASTLOCK = 1), quyền sở hữu bus không được phép chuyển sang Master khác
        if (dbg_hmastlock && (dbg_hmaster != 2'd1))
            $fatal(1, "LỖI GIAO THỨC: Quyền sở hữu bus thay đổi trong giao dịch khóa của M1 tại %0t", $time);

        monitor_valid <= 1'b1;
        prev_hready   <= dbg_hready;
        prev_haddr    <= dbg_haddr;
        prev_htrans   <= dbg_htrans;
        prev_hwrite   <= dut.HWRITE;
        prev_hsize    <= dut.HSIZE;
        prev_hburst   <= dut.HBURST;
        prev_hwdata   <= dut.HWDATA;
    end
end
