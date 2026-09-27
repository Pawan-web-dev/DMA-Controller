// ============================================================================
// uart_assertions.sv - simple SVA that matches DUT timing
// ============================================================================
`ifndef UART_ASSERTIONS_SV
`define UART_ASSERTIONS_SV

module uart_assertions #(
  parameter int SYS_FREQ  = 50_000_000,
  parameter int BAUD_RATE = 9600,
  parameter int DATABITS  = 8
)(
  input logic       clk,
  input logic       reset,
  input logic       tx_en,
  input logic [7:0] tx_data_in,
  input logic       tx_data,
  input logic       tx_busy,
  input logic       tx_done,
  input logic       rx_data,
  input logic [7:0] rx_data_out,
  input logic       rx_done,
  input logic       parity_error,
  input logic       stop_error,
  input logic       frame_error,
  input logic       baud_tick,
  input logic       tick_16x
);

  // Idle line after reset
  property p_idle_after_reset;
    @(posedge clk) $fell(reset) |=> (tx_data === 1'b1);
  endproperty
  A_IDLE_AFTER_RESET: assert property (p_idle_after_reset)
    else $error("TX line not idle after reset");

  // Idle line while no transmission
  property p_idle_line;
    @(posedge clk) disable iff (reset)
      (!tx_busy && !tx_en && !tx_done) |-> (tx_data === 1'b1);
  endproperty
  A_IDLE_LINE: assert property (p_idle_line)
    else $error("TX line low while idle");

  // tx_done is a single-cycle pulse
  property p_tx_done_pulse;
    @(posedge clk) disable iff (reset) tx_done |=> !tx_done;
  endproperty
  A_TX_DONE_PULSE: assert property (p_tx_done_pulse)
    else $error("tx_done not a single-cycle pulse");

  // rx_done is a single-cycle pulse
  property p_rx_done_pulse;
    @(posedge clk) disable iff (reset) rx_done |=> !rx_done;
  endproperty
  A_RX_DONE_PULSE: assert property (p_rx_done_pulse)
    else $error("rx_done not a single-cycle pulse");

  // baud_tick follows a tick_16x by one cycle (registered)
  property p_baud_tick_after_16x;
    @(posedge clk) disable iff (reset) $rose(baud_tick) |-> $past(tick_16x, 1);
  endproperty
  A_BAUD_TICK_AFTER_16X: assert property (p_baud_tick_after_16x)
    else $error("baud_tick not preceded by tick_16x");

  // stop_error implies frame_error
  property p_stop_implies_frame;
    @(posedge clk) disable iff (reset) stop_error |-> frame_error;
  endproperty
  A_STOP_IMPLIES_FRAME: assert property (p_stop_implies_frame)
    else $error("stop_error without frame_error");

  // No X on TX line
  property p_no_x_tx;
    @(posedge clk) disable iff (reset) !$isunknown(tx_data);
  endproperty
  A_NO_X_TX: assert property (p_no_x_tx)
    else $error("TX data X");

endmodule

`endif