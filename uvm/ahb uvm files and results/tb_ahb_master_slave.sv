`timescale 1ns/1ps

module tb_ahb_master_slave;

    localparam int ADDR_WIDTH    = 32;
    localparam int DATA_WIDTH    = 32;
    localparam int MAX_BURST_LEN = 16;
    localparam int FIFO_DEPTH    = 4;
    localparam int LEN_WIDTH     = $clog2(MAX_BURST_LEN + 1);
    localparam time CLK_PERIOD   = 10ns;

    localparam logic [1:0] ST_BURST_ENC = 2'd2;

    logic HCLK = 1'b0;
    logic HRESETn;
    always #(CLK_PERIOD/2) HCLK = ~HCLK;

    logic [ADDR_WIDTH-1:0] HADDR;
    logic [1:0]            HTRANS;
    logic                  HWRITE;
    logic [2:0]            HSIZE, HBURST;
    logic [DATA_WIDTH-1:0] HWDATA, HRDATA;
    logic                  HREADYOUT;
    logic                  HRESP_slave;
    logic                  inject_error;
    wire                   HRESP_to_master = HRESP_slave | inject_error;

    logic                   req_start, req_write;
    logic [LEN_WIDTH-1:0]   req_burst_len;
    logic [ADDR_WIDTH-1:0]  req_addr;
    logic [DATA_WIDTH-1:0]  tb_wdata [0:MAX_BURST_LEN-1];
    logic [DATA_WIDTH-1:0]  tb_rdata [0:MAX_BURST_LEN-1];
    logic                   req_done, req_error, req_reject;

    logic [1:0]             cfg_wait_states;

    ahb_master #(
        .ADDR_WIDTH   (ADDR_WIDTH),
        .DATA_WIDTH   (DATA_WIDTH),
        .MAX_BURST_LEN(MAX_BURST_LEN)
    ) u_master (
        .HCLK         (HCLK),
        .HRESETn      (HRESETn),
        .HREADY       (HREADYOUT),
        .HRDATA       (HRDATA),
        .HRESP        (HRESP_to_master),
        .HADDR        (HADDR),
        .HTRANS       (HTRANS),
        .HWRITE       (HWRITE),
        .HSIZE        (HSIZE),
        .HBURST       (HBURST),
        .HWDATA       (HWDATA),
        .req_start    (req_start),
        .req_write    (req_write),
        .req_burst_len(req_burst_len),
        .req_addr     (req_addr),
        .req_wdata    (tb_wdata),
        .resp_rdata   (tb_rdata),
        .req_done     (req_done),
        .req_error    (req_error),
        .req_reject   (req_reject)
    );

    ahb_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_slave (
        .HCLK           (HCLK),
        .HRESETn        (HRESETn),
        .HSEL           (1'b1),
        .HADDR          (HADDR),
        .HTRANS         (HTRANS),
        .HWRITE         (HWRITE),
        .HSIZE          (HSIZE),
        .HBURST         (HBURST),
        .HWDATA         (HWDATA),
        .HREADY         (HREADYOUT),
        .HRDATA         (HRDATA),
        .HREADYOUT      (HREADYOUT),
        .HRESP          (HRESP_slave),
        .cfg_wait_states(cfg_wait_states)
    );

    logic [DATA_WIDTH-1:0] golden_q [$];
    int pass_count = 0;
    int fail_count = 0;

    task automatic check(input bit cond, input string msg);
        if (cond) begin
            pass_count++;
            $display("[%0t] PASS: %s", $time, msg);
        end else begin
            fail_count++;
            $display("[%0t] FAIL: %s", $time, msg);
        end
    endtask

    task automatic issue_burst(input bit is_write,
                               input logic [ADDR_WIDTH-1:0] addr,
                               input int len);
        begin
            @(negedge HCLK);
            req_addr      = addr;
            req_write     = is_write;
            req_burst_len = len[LEN_WIDTH-1:0];
            req_start     = 1'b1;
            @(negedge HCLK);
            req_start     = 1'b0;
        end
    endtask

    task automatic do_write(input logic [ADDR_WIDTH-1:0] addr,
                            input int len,
                            input int seed);
        begin
            for (int i = 0; i < len; i++) begin
                tb_wdata[i] = seed + i;
                golden_q.push_back(seed + i);
            end
            issue_burst(1'b1, addr, len);
            wait (req_done === 1'b1);
            check(req_error === 1'b0,
                  $sformatf("write burst len=%0d completed without error", len));
            @(negedge HCLK);
        end
    endtask

    task automatic do_read(input logic [ADDR_WIDTH-1:0] addr, input int len);
        logic [DATA_WIDTH-1:0] expected;
        begin
            issue_burst(1'b0, addr, len);
            wait (req_done === 1'b1);
            check(req_error === 1'b0,
                  $sformatf("read burst len=%0d completed without error", len));
            for (int i = 0; i < len; i++) begin
                expected = golden_q.pop_front();
                check(tb_rdata[i] === expected,
                      $sformatf("read beat %0d: expected 0x%08h, got 0x%08h",
                                i, expected, tb_rdata[i]));
            end
            @(negedge HCLK);
        end
    endtask

    task automatic drain_stale(input logic [ADDR_WIDTH-1:0] addr);
        int n;
        begin
            n = int'(u_slave.fifo_count);
            $display("[%0t] Draining %0d stale FIFO entries", $time, n);
            if (n > 0) begin
                issue_burst(1'b0, addr, n);
                wait (req_done === 1'b1);
                @(negedge HCLK);
            end
        end
    endtask

    task automatic check_invalid_len(input logic [ADDR_WIDTH-1:0] addr,
                                     input int len,
                                     input string label);
        bit bad, reject_seen;
        begin
            bad         = 1'b0;
            reject_seen = 1'b0;
            @(negedge HCLK);
            req_addr      = addr;
            req_write     = 1'b1;
            req_burst_len = len[LEN_WIDTH-1:0];
            req_start     = 1'b1;

            repeat (2) begin
                @(negedge HCLK);
                if (req_done === 1'b1 || req_error === 1'b1 || HTRANS !== 2'b00)
                    bad = 1'b1;
                if (req_reject === 1'b1)
                    reject_seen = 1'b1;
            end
            req_start = 1'b0;

            repeat (6) begin
                @(negedge HCLK);
                if (req_done === 1'b1 || req_error === 1'b1 || HTRANS !== 2'b00)
                    bad = 1'b1;
                if (req_reject === 1'b1)
                    reject_seen = 1'b1;
            end
            check(!bad, label);
            check(reject_seen, "req_reject pulsed for invalid burst length");
        end
    endtask

    // ------------------------------------------------------------------
    // Robust wait-state monitor.
    //
    // The slave inserts `cfg_wait_states` stall cycles per beat by driving
    // HREADYOUT low while `valid_q==1 && wait_cnt < cfg_wait_states`.  We
    // count those cycles exactly, sampling at posedges, but we deliberately
    // sync to a posedge AFTER `valid_q` has been captured so we don't
    // double-count the delta cycle in which `wait()` unblocks.
    // ------------------------------------------------------------------
    task automatic monitor_wait_cycles(output int wait_cycles);
        begin
            wait_cycles = 0;
            @(posedge HCLK);
            wait (u_slave.valid_q === 1'b1);
            @(posedge HCLK);                  // skip the capture edge
            while (u_master.state === ST_BURST_ENC) begin
                if (u_slave.valid_q === 1'b1 &&
                    u_slave.wait_cnt < cfg_wait_states)
                    wait_cycles++;
                @(posedge HCLK);
            end
        end
    endtask

    task automatic do_write_count_waits(input logic [ADDR_WIDTH-1:0] addr,
                                        input int len,
                                        input int seed,
                                        output int wait_cycles);
        begin
            for (int i = 0; i < len; i++) begin
                tb_wdata[i] = seed + i;
                golden_q.push_back(seed + i);
            end
            fork
                begin
                    issue_burst(1'b1, addr, len);
                    wait (req_done === 1'b1);
                end
                begin
                    monitor_wait_cycles(wait_cycles);
                end
            join
            @(negedge HCLK);
        end
    endtask

    initial begin
        req_start       = 1'b0;
        req_write       = 1'b0;
        req_burst_len   = '0;
        req_addr        = '0;
        cfg_wait_states = 2'd0;
        inject_error    = 1'b0;
        HRESETn         = 1'b0;
        repeat (5) @(posedge HCLK);
        HRESETn = 1'b1;
        @(negedge HCLK);

        $display("\n--- T1: single beat and short burst write/read ---");
        do_write(32'h0000_1000, 1, 32'hA000_0000);
        do_read (32'h0000_1000, 1);
        do_write(32'h0000_1100, 2, 32'hA100_0000);
        do_read (32'h0000_1100, 2);

        $display("\n--- T2: FIFO boundary (len == FIFO_DEPTH=%0d) ---", FIFO_DEPTH);
        do_write(32'h0000_2000, FIFO_DEPTH, 32'hB000_0000);
        do_read (32'h0000_2000, FIFO_DEPTH);

        $display("\n--- T3: wait-state insertion (cfg_wait_states=2) ---");
        cfg_wait_states = 2'd2;
        begin
            int low_cycles;
            fork
                begin
                    do_write(32'h0000_3000, 1, 32'hC000_0000);
                end
                begin
                    monitor_wait_cycles(low_cycles);
                end
            join
            check(low_cycles === 2,
                  $sformatf("cfg_wait_states=2 inserted %0d wait cycle(s)", low_cycles));
        end
        do_read(32'h0000_3000, 1);
        cfg_wait_states = 2'd0;

        begin
            int low_cycles0;
            fork
                begin
                    do_write(32'h0000_3100, 1, 32'hC100_0000);
                end
                begin
                    monitor_wait_cycles(low_cycles0);
                end
            join
            check(low_cycles0 === 0,
                  $sformatf("cfg_wait_states=0 inserted %0d wait cycle(s)", low_cycles0));
        end
        do_read(32'h0000_3100, 1);

        $display("\n--- T3b: per-beat wait-state regression (multi-beat burst, cfg_wait_states=1) ---");
        cfg_wait_states = 2'd1;
        begin
            int total_waits;
            do_write_count_waits(32'h0000_3200, FIFO_DEPTH, 32'hC200_0000, total_waits);
            check(total_waits === FIFO_DEPTH,
                  $sformatf("cfg_wait_states=1 inserted %0d total wait cycle(s) across %0d beats (expected %0d, 1 per beat)",
                            total_waits, FIFO_DEPTH, FIFO_DEPTH));
        end
        do_read(32'h0000_3200, FIFO_DEPTH);
        cfg_wait_states = 2'd0;

        $display("\n--- T4: invalid burst length rejected ---");
        check_invalid_len(32'h0000_4000, 0,
            "req_burst_len=0 was ignored (no req_done/req_error, HTRANS stayed IDLE)");
        check_invalid_len(32'h0000_4100, MAX_BURST_LEN + 1,
            "req_burst_len > MAX_BURST_LEN was ignored (no req_done/req_error, HTRANS stayed IDLE)");

        do_write(32'h0000_4200, 1, 32'hD000_0000);
        do_read (32'h0000_4200, 1);

        $display("\n--- T5: error injection mid-burst (len=4) ---");
        begin
            int wr_len;
            wr_len = 4;
            for (int i = 0; i < wr_len; i++) tb_wdata[i] = 32'hE000_0000 + i;

            fork
                begin
                    issue_burst(1'b1, 32'h0000_5000, wr_len);
                    wait (req_done === 1'b1);
                end
                begin
                    wait (u_master.state === ST_BURST_ENC && u_master.beat_cnt === 1);
                    @(negedge HCLK);
                    inject_error = 1'b1;
                    @(negedge HCLK);
                    inject_error = 1'b0;
                end
            join
            check(req_error === 1'b1, "req_error asserted on injected HRESP");
            check(req_done  === 1'b1, "req_done asserted together with req_error");
        end
        @(negedge HCLK);

        drain_stale(32'h0000_5000);

        do_write(32'h0000_5100, 1, 32'hF000_0000);
        do_read (32'h0000_5100, 1);

        $display("\n--- T6: HREADYOUT deasserts when a write burst exactly fills the FIFO ---");
        begin
            bit stall_seen;
            stall_seen = 1'b0;
            for (int i = 0; i < FIFO_DEPTH; i++) begin
                tb_wdata[i] = 32'h6000_0000 + i;
                golden_q.push_back(tb_wdata[i]);   // record expected data
            end

            fork
                begin
                    issue_burst(1'b1, 32'h0000_6000, FIFO_DEPTH);
                    wait (req_done === 1'b1);
                end
                begin
                    @(posedge HCLK);
                    wait (u_slave.valid_q === 1'b1 && u_slave.write_q === 1'b1);
                    while (u_master.state === ST_BURST_ENC) begin
                        if (HREADYOUT === 1'b0 && u_slave.fifo_count == FIFO_DEPTH)
                            stall_seen = 1'b1;
                        @(posedge HCLK);
                    end
                end
            join
            check(!stall_seen,
                  "a burst that exactly fills the FIFO completes its own last beat before backpressure would be needed");
            do_read(32'h0000_6000, FIFO_DEPTH);
        end

        $display("\n=====================================");
        $display(" TEST SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        $display("=====================================");
        if (fail_count == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: FAILURES DETECTED");

        $finish;
    end

    initial begin
        #(CLK_PERIOD * 5000);
        $display("[%0t] ERROR: testbench timeout - a test likely hung", $time);
        $finish;
    end

endmodule