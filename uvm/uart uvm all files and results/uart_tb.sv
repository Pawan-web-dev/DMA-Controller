// ============================================================================
// uart_tb.sv - UART testbench with correct error-flag sampling
// ============================================================================
`timescale 1ns/1ps

module uart_tb;

    localparam int SYS_FREQ     = 50_000_000;
    localparam int BAUD_RATE    = 9600;
    localparam int DATABITS     = 8;
    localparam int PARITY_EN    = 1;
    localparam int PARITY_TYPE  = 0;
    localparam int M_16X        = SYS_FREQ / (BAUD_RATE * 16);
    localparam int CLKS_PER_BIT = M_16X * 16;

    logic clk   = 1'b0;
    logic reset = 1'b1;
    always #10 clk = ~clk;

    logic        tx_en;
    logic [7:0]  tx_data_in;
    logic        tx_data;
    logic        tx_busy;
    logic        tx_done;

    logic        rx_data_tb;
    logic        loopback_en;
    logic [7:0]  rx_data_out;
    logic        rx_done;

    logic        parity_error;
    logic        stop_error;
    logic        frame_error;
    logic        baud_tick;
    logic        tick_16x;

    wire rx_data = loopback_en ? tx_data : rx_data_tb;

    uart_top #(
        .SYS_FREQ    (SYS_FREQ),
        .BAUD_RATE   (BAUD_RATE),
        .DATABITS    (DATABITS),
        .PARITY_EN   (PARITY_EN),
        .PARITY_TYPE (PARITY_TYPE)
    ) dut (
        .clk          (clk),
        .reset        (reset),
        .tx_en        (tx_en),
        .tx_data_in   (tx_data_in),
        .tx_data      (tx_data),
        .tx_busy      (tx_busy),
        .tx_done      (tx_done),
        .rx_data      (rx_data),
        .rx_data_out  (rx_data_out),
        .rx_done      (rx_done),
        .parity_error (parity_error),
        .stop_error   (stop_error),
        .frame_error  (frame_error),
        .baud_tick    (baud_tick),
        .tick_16x     (tick_16x)
    );

    // ----- Assertions instantiated here -----
    uart_assertions #(
        .SYS_FREQ  (SYS_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .DATABITS  (DATABITS)
    ) u_assert_inst (
        .clk          (clk),
        .reset        (reset),
        .tx_en        (tx_en),
        .tx_data_in   (tx_data_in),
        .tx_data      (tx_data),
        .tx_busy      (tx_busy),
        .tx_done      (tx_done),
        .rx_data      (rx_data),
        .rx_data_out  (rx_data_out),
        .rx_done      (rx_done),
        .parity_error (parity_error),
        .stop_error   (stop_error),
        .frame_error  (frame_error),
        .baud_tick    (baud_tick),
        .tick_16x     (tick_16x)
    );

    int pass_count = 0;
    int fail_count = 0;

    task automatic check(input string name, input bit cond);
        if (cond) begin
            pass_count++;
            $display("  [PASS] %s", name);
        end else begin
            fail_count++;
            $display("  [FAIL] %s", name);
        end
    endtask

    task automatic send_tx_byte(input logic [7:0] data);
        while (tx_busy) @(posedge clk);
        @(posedge clk);
        tx_data_in <= data;
        tx_en      <= 1'b1;
        @(posedge clk);
        tx_en <= 1'b0;
        wait (tx_done == 1'b1);
        @(posedge clk);
    endtask

    task automatic capture_tx_byte(output logic [7:0] data_out,
                                   output logic       par_bit,
                                   output logic       stop_bit);
        int half = CLKS_PER_BIT / 2;
        wait (tx_busy == 1'b1);
        repeat (half) @(posedge clk);
        for (int i = 0; i < DATABITS; i++) begin
            repeat (CLKS_PER_BIT) @(posedge clk);
            data_out[i] = tx_data;
        end
        repeat (CLKS_PER_BIT) @(posedge clk);
        par_bit = tx_data;
        repeat (CLKS_PER_BIT) @(posedge clk);
        stop_bit = tx_data;
    endtask

    task automatic drive_rx_byte(input logic [7:0] data,
                                 input bit       bad_parity = 0,
                                 input bit       bad_stop   = 0);
        logic pbit;
        rx_data_tb <= 1'b0;
        repeat (CLKS_PER_BIT) @(posedge clk);
        for (int i = 0; i < DATABITS; i++) begin
            rx_data_tb <= data[i];
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
        if (PARITY_EN) begin
            pbit = (PARITY_TYPE == 0) ? ^data : ~(^data);
            if (bad_parity) pbit = ~pbit;
            rx_data_tb <= pbit;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
        rx_data_tb <= bad_stop ? 1'b0 : 1'b1;
        repeat (CLKS_PER_BIT) @(posedge clk);
        rx_data_tb <= 1'b1;
        repeat (CLKS_PER_BIT) @(posedge clk);
    endtask

    // Helper: sample the error flags at the moment rx_done pulses
    task automatic wait_and_capture_rx(output logic [7:0] data,
                                       output logic       perr,
                                       output logic       serr,
                                       output logic       ferr);
        wait (rx_done == 1'b1);
        data = rx_data_out;
        perr = parity_error;
        serr = stop_error;
        ferr = frame_error;
        @(posedge clk);
    endtask

    initial begin
        tx_en       = 1'b0;
        tx_data_in  = 8'h00;
        rx_data_tb  = 1'b1;
        loopback_en = 1'b0;

        repeat (20) @(posedge clk);
        reset = 1'b0;
        repeat (20) @(posedge clk);

        $display("");
        $display("============================================================");
        $display(" UART Testbench");
        $display(" SYS_FREQ=%0d  BAUD_RATE=%0d  M_16X=%0d  CLKS_PER_BIT=%0d",
                 SYS_FREQ, BAUD_RATE, M_16X, CLKS_PER_BIT);
        $display("============================================================");
        $display("");

        // ---- TEST 1 ----
        $display("[TEST 1] TX basic transmission");
        begin
            logic [7:0] cap;
            logic par, stp;
            fork
                send_tx_byte(8'hA5);
                capture_tx_byte(cap, par, stp);
            join
            check("TX 0xA5 completes", cap === 8'hA5);
        end
        $display("");

        // ---- TEST 2 ----
        $display("[TEST 2] TX bit patterns");
        begin
            logic [7:0] pat [6];
            logic [7:0] cap;
            logic par, stp;
            pat[0]=8'h01; pat[1]=8'h80; pat[2]=8'hAA;
            pat[3]=8'h55; pat[4]=8'h00; pat[5]=8'hFF;
            for (int i = 0; i < 6; i++) begin
                fork
                    send_tx_byte(pat[i]);
                    capture_tx_byte(cap, par, stp);
                join
                check($sformatf("TX 0x%02h", pat[i]), cap === pat[i]);
            end
        end
        $display("");

        // ---- TEST 3 ----
        $display("[TEST 3] RX reception");
        begin
            logic [7:0] d; logic pe,se,fe;
            fork
                drive_rx_byte(8'hC3);
                wait_and_capture_rx(d, pe, se, fe);
            join
            check("RX 0xC3 data",      d === 8'hC3);
            check("RX 0xC3 no errors", !pe && !se && !fe);
        end
        begin
            logic [7:0] rxb [3]; logic [7:0] d; logic pe,se,fe;
            rxb[0]=8'h5A; rxb[1]=8'h00; rxb[2]=8'hFF;
            for (int i = 0; i < 3; i++) begin
                fork
                    drive_rx_byte(rxb[i]);
                    wait_and_capture_rx(d, pe, se, fe);
                join
                check($sformatf("RX 0x%02h", rxb[i]), d === rxb[i]);
            end
        end
        $display("");

        // ---- TEST 4 ----
        $display("[TEST 4] Parity error detection");
        begin
            logic [7:0] d; logic pe,se,fe;
            fork
                drive_rx_byte(8'h5A, .bad_parity(1'b1));
                wait_and_capture_rx(d, pe, se, fe);
            join
            check("Parity error detected", pe === 1'b1);
        end
        $display("");

        // ---- TEST 5 ----
        $display("[TEST 5] Frame error detection");
        begin
            logic [7:0] d; logic pe,se,fe;
            fork
                drive_rx_byte(8'h5A, .bad_parity(1'b0), .bad_stop(1'b1));
                wait_and_capture_rx(d, pe, se, fe);
            join
            check("Frame error detected", fe === 1'b1);
            check("Stop error detected",  se === 1'b1);
        end
        $display("");

        // ---- TEST 6 ----
        $display("[TEST 6] Full duplex (TX + RX simultaneously)");
        begin
            logic [7:0] tx_cap, rx_d;
            logic tpar, tstp;
            logic pe, se, fe;
            fork
                send_tx_byte(8'h3C);
                capture_tx_byte(tx_cap, tpar, tstp);
                drive_rx_byte(8'hA7);
                wait_and_capture_rx(rx_d, pe, se, fe);
            join
            check("TX during RX", tx_cap === 8'h3C);
            check("RX during TX", rx_d  === 8'hA7);
        end
        $display("");

        // ---- TEST 7 ----
        $display("[TEST 7] Loopback (TX -> RX)");
        begin
            int ok = 0;
            logic [7:0] lp [4];
            logic [7:0] rx_d;
            logic pe, se, fe;
            lp[0]=8'h11; lp[1]=8'h22; lp[2]=8'h33; lp[3]=8'h44;
            loopback_en = 1'b1;
            repeat (20) @(posedge clk);
            for (int i = 0; i < 4; i++) begin
                fork
                    send_tx_byte(lp[i]);
                    wait_and_capture_rx(rx_d, pe, se, fe);
                join
                if (rx_d === lp[i]) ok++;
            end
            loopback_en = 1'b0;
            repeat (20) @(posedge clk);
            check($sformatf("Loopback %0d/4 correct", ok), ok == 4);
        end
        $display("");

        $display("============================================================");
        $display(" RESULTS: %0d tests, %0d PASS, %0d FAIL",
                 pass_count + fail_count, pass_count, fail_count);
        if (fail_count == 0) $display(" ALL TESTS PASSED");
        else                 $display(" SOME TESTS FAILED");
        $display("============================================================");
        $display("");

        $finish;
    end

endmodule