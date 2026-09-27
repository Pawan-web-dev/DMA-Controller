

`timescale 1ns / 1ps
module reset_sync (
    input  logic clk,
    input  logic async_reset,
    output logic sync_reset
);
    logic reset_sync0;

    always_ff @(posedge clk or posedge async_reset) begin
        if (async_reset) begin
            reset_sync0 <= 1'b1;
            sync_reset  <= 1'b1;
        end else begin
            reset_sync0 <= 1'b0;
            sync_reset  <= reset_sync0;
        end
    end
endmodule : reset_sync

module baud_gen #(
    parameter SYS_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input  logic clk,
    input  logic reset,
    output logic baud_tick,
    output logic tick_16x
);

    localparam int M_16X = SYS_FREQ / (BAUD_RATE * 16);
    
    initial begin
        if (M_16X < 2) begin
            $fatal(1, "baud_gen: Invalid SYS_FREQ (%0d) / BAUD_RATE (%0d) combination. M_16X=%0d must be >= 2",
                      SYS_FREQ, BAUD_RATE, M_16X);
        end
    end
    localparam int CTR_WIDTH = $clog2(M_16X + 1);
    logic [CTR_WIDTH-1:0] count_16x;
    logic [3:0] count_1x;

    // 16x Baud Clock Generator
    always_ff @(posedge clk) begin
        if (reset) begin
            count_16x <= '0;
            tick_16x  <= 1'b0;
        end else begin
            if (count_16x == (M_16X - 1)) begin
                count_16x <= '0;
                tick_16x  <= 1'b1;
            end else begin
                count_16x <= count_16x + 1'b1;
                tick_16x  <= 1'b0;
            end
        end
    end

    // Baud Rate Clock Generator (1x) - divides 16x by 16
    always_ff @(posedge clk) begin
        if (reset) begin
            count_1x  <= '0;
            baud_tick <= 1'b0;
        end else if (tick_16x) begin
            if (count_1x == 4'd15) begin
                count_1x  <= '0;
                baud_tick <= 1'b1;
            end else begin
                count_1x  <= count_1x + 1'b1;
                baud_tick <= 1'b0;
            end
        end else begin
            baud_tick <= 1'b0;
        end
    end

endmodule : baud_gen

// ============================================================================
// UART TRANSMITTER
// ============================================================================
module uart_tx #(
    parameter DATABITS    = 8,
    parameter PARITY_EN   = 1,
    parameter PARITY_TYPE = 0  // 0=even, 1=odd
)(
    input  logic                   clk,
    input  logic                   reset,
    input  logic [DATABITS-1:0]    data_in,
    input  logic                   tx_en,
    input  logic                   baud_tick,
    output logic                   tx_data,
    output logic                   tx_busy,
    output logic                   tx_done
);

    typedef enum logic [2:0] {IDLE, START, DATA, PARITY, STOP} state_t;
    state_t cs;

    logic [$clog2(DATABITS):0] bit_count;  // Extra bit to handle DATABITS=1 edge case
    logic [DATABITS-1:0]       data_reg;
    logic                      parity_bit;
    logic                      tx_en_d;
    logic                      tx_en_rise;

    // Edge detection for tx_en
    always_ff @(posedge clk) begin
        if (reset)
            tx_en_d <= 1'b0;
        else
            tx_en_d <= tx_en;
    end

    assign tx_en_rise = tx_en & ~tx_en_d;

    // ========================================================================
    // TX START REQUEST LATCHING
    // Prevents start-request miss when tx_en_rise and baud_tick don't align
    // ========================================================================
    logic tx_start_pending;
    logic [DATABITS-1:0] data_latched;

    always_ff @(posedge clk) begin
        if (reset) begin
            tx_start_pending <= 1'b0;
            data_latched     <= '0;
        end else if (tx_en_rise && ~tx_busy) begin
            // Only latch if not currently transmitting (addresses minor issue #1)
            // This prevents overwriting data_in if tx_en rises during transmission
            tx_start_pending <= 1'b1;
            data_latched     <= data_in;
        end else if (baud_tick && cs == IDLE && tx_start_pending) begin
            // Clear pending flag when request is consumed
            tx_start_pending <= 1'b0;
        end
    end

    // ========================================================================
    // STATE MACHINE
    // ========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            cs         <= IDLE;
            bit_count  <= '0;
            data_reg   <= '0;
            tx_busy    <= 1'b0;
            parity_bit <= 1'b0;
            tx_done    <= 1'b0;
        end else begin
            tx_done <= 1'b0;  // Default: no pulse

            if (baud_tick) begin
                case (cs)
                    IDLE: begin
                        tx_busy <= 1'b0;
                        if (tx_start_pending) begin
                            cs         <= START;
                            tx_busy    <= 1'b1;
                            data_reg   <= data_latched;  // Use latched data
                            bit_count  <= '0;
                            parity_bit <= (PARITY_TYPE == 0) ? ^data_latched : ~(^data_latched);
                        end
                    end

                    START: begin
                        cs <= DATA;
                    end

                    DATA: begin
                        if (bit_count == DATABITS - 1) begin
                            cs        <= PARITY_EN ? PARITY : STOP;
                            bit_count <= '0;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end

                    PARITY: begin
                        cs <= STOP;
                    end

                    STOP: begin
                        cs      <= IDLE;
                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;  // Single-cycle pulse
                    end

                    default: begin
                        cs <= IDLE;
                    end
                endcase
            end
        end
    end

    // Output logic (combinational)
    always_comb begin
        case (cs)
            START:   tx_data = 1'b0;
            DATA:    tx_data = data_reg[bit_count];
            PARITY:  tx_data = parity_bit;
            default: tx_data = 1'b1;  // IDLE and STOP = high (idle line)
        endcase
    end

endmodule : uart_tx

// ============================================================================
// UART RECEIVER
// ============================================================================
module uart_rx #(
    parameter DATABITS    = 8,
    parameter PARITY_EN   = 1,
    parameter PARITY_TYPE = 0  // 0=even, 1=odd
)(
    input  logic                 clk,
    input  logic                 reset,
    input  logic                 tick_16x,
    input  logic                 rx_data,
    output logic [DATABITS-1:0]  data_out,
    output logic                 rx_done,
    output logic                 parity_error,
    output logic                 stop_error,
    output logic                 frame_error
);

    // Input synchronizer (double-flop for metastability)
    logic rx_sync0, rx_sync1;
    always_ff @(posedge clk) begin
        if (reset) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx_data;
            rx_sync1 <= rx_sync0;
        end
    end

    typedef enum logic [2:0] {IDLE, START, DATA, PARITY, STOP} state_t;
    state_t cs;

    logic [3:0] sample_count;
    logic [$clog2(DATABITS):0] bit_count;  // Extra bit for edge case
    logic [DATABITS-1:0] data_reg;
    logic parity_calc;
    logic parity_received;
    logic rx_done_r;

    // Parity calculation
    always_comb begin
        parity_calc = (PARITY_TYPE == 0) ? ^data_reg : ~(^data_reg);
    end

    // ========================================================================
    // STATE MACHINE
    // Sampling at count=7 and count=15 centers samples within bit periods
    // (16x sampling: middle is at 8, but 7 is close enough and widely used)
    // ========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            cs              <= IDLE;
            sample_count    <= '0;
            bit_count       <= '0;
            data_reg        <= '0;
            data_out        <= '0;
            rx_done_r       <= 1'b0;
            parity_error    <= 1'b0;
            stop_error      <= 1'b0;
            frame_error     <= 1'b0;
            parity_received <= 1'b0;
        end else begin
            rx_done_r <= 1'b0;  // Default: no pulse

            if (tick_16x) begin
                case (cs)
                    IDLE: begin
                        sample_count <= '0;
                        parity_error <= 1'b0;
                        stop_error   <= 1'b0;
                        frame_error  <= 1'b0;

                        // Look for START bit (0)
                        if (rx_sync1 == 1'b0) begin
                            cs <= START;
                            sample_count <= 1'b0;
                        end
                    end

                    START: begin
                        // Sample start bit at middle (count=7, close to ideal middle at 8)
                        sample_count <= sample_count + 1'b1;
                        if (sample_count == 4'd7) begin
                            if (rx_sync1 == 1'b0) begin
                                // Valid START bit
                                cs           <= DATA;
                                sample_count <= '0;
                                bit_count    <= '0;
                            end else begin
                                // False START (glitch/noise)
                                cs           <= IDLE;
                                sample_count <= '0;
                            end
                        end
                    end

                    DATA: begin
                        // Sample data bits at middle (count=15, which is middle of 16 ticks)
                        sample_count <= sample_count + 1'b1;
                        if (sample_count == 4'd15) begin
                            sample_count        <= '0;
                            data_reg[bit_count] <= rx_sync1;
                            
                            if (bit_count == DATABITS - 1) begin
                                bit_count <= '0;
                                cs        <= PARITY_EN ? PARITY : STOP;
                            end else begin
                                bit_count <= bit_count + 1'b1;
                            end
                        end
                    end

                    PARITY: begin
                        // Sample parity bit at middle
                        sample_count <= sample_count + 1'b1;
                        if (sample_count == 4'd15) begin
                            sample_count    <= '0;
                            parity_received <= rx_sync1;
                            cs              <= STOP;
                        end
                    end

                    STOP: begin
                        // Sample stop bit at middle (should be 1)
                        sample_count <= sample_count + 1'b1;
                        if (sample_count == 4'd15) begin
                            // Check stop bit validity
                            if (rx_sync1 != 1'b1) begin
                                stop_error  <= 1'b1;
                                // frame_error and stop_error are identical (minor issue #5)
                                // Kept separate for API clarity; can be consolidated if desired
                                frame_error <= 1'b1;
                            end

                            // Check parity if enabled
                            if (PARITY_EN)
                                parity_error <= (parity_received != parity_calc);
                            
                            // Output received data
                            data_out <= data_reg;
                            rx_done_r <= 1'b1;  // Single-cycle pulse
                            
                            // Back to IDLE
                            cs           <= IDLE;
                            sample_count <= '0;
                        end
                    end

                    default: begin
                        cs <= IDLE;
                    end
                endcase
            end
        end
    end

    assign rx_done = rx_done_r;

endmodule : uart_rx

// ============================================================================
// UART TOP MODULE
// ============================================================================
module uart_top #(
    parameter SYS_FREQ    = 50_000_000,
    parameter BAUD_RATE   = 9600,
    parameter DATABITS    = 8,
    parameter PARITY_EN   = 1,
    parameter PARITY_TYPE = 0
)(
    input  logic                  clk,
    input  logic                  reset,
    // TX Interface
    input  logic                  tx_en,
    input  logic [DATABITS-1:0]   tx_data_in,
    output logic                  tx_data,
    output logic                  tx_busy,
    output logic                  tx_done,
    // RX Interface
    input  logic                  rx_data,
    output logic [DATABITS-1:0]   rx_data_out,
    output logic                  rx_done,
    // Error Flags
    output logic                  parity_error,
    output logic                  stop_error,
    output logic                  frame_error,
    // Timing outputs (for debug/observation)
    output logic                  baud_tick,
    output logic                  tick_16x
);

    logic sync_reset;

    // Reset synchronization
    reset_sync reset_sync_inst (
        .clk         (clk),
        .async_reset (reset),
        .sync_reset  (sync_reset)
    );

    // Baud rate generator
    baud_gen #(
        .SYS_FREQ (SYS_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) baud_inst (
        .clk      (clk),
        .reset    (sync_reset),
        .baud_tick(baud_tick),
        .tick_16x (tick_16x)
    );

    // UART Transmitter
    uart_tx #(
        .DATABITS   (DATABITS),
        .PARITY_EN  (PARITY_EN),
        .PARITY_TYPE(PARITY_TYPE)
    ) tx_inst (
        .clk      (clk),
        .reset    (sync_reset),
        .data_in  (tx_data_in),
        .tx_en    (tx_en),
        .baud_tick(baud_tick),
        .tx_data  (tx_data),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done)
    );

    // UART Receiver
    uart_rx #(
        .DATABITS   (DATABITS),
        .PARITY_EN  (PARITY_EN),
        .PARITY_TYPE(PARITY_TYPE)
    ) rx_inst (
        .clk         (clk),
        .reset       (sync_reset),
        .rx_data     (rx_data),
        .tick_16x    (tick_16x),
        .data_out    (rx_data_out),
        .rx_done     (rx_done),
        .parity_error(parity_error),
        .stop_error  (stop_error),
        .frame_error (frame_error)
    );

endmodule : uart_top
