// ============================================================================
// uart_if.sv - Virtual interface for UART DUT
// ============================================================================
`ifndef UART_IF_SV
`define UART_IF_SV

interface uart_if (input logic clk);

  logic        reset;
  logic        tx_en;
  logic [7:0]  tx_data_in;
  logic        tx_data;
  logic        tx_busy;
  logic        tx_done;
  logic        rx_data;
  logic [7:0]  rx_data_out;
  logic        rx_done;
  logic        parity_error;
  logic        stop_error;
  logic        frame_error;
  logic        baud_tick;
  logic        tick_16x;

  // Driver clocking block
  clocking drv_cb @(posedge clk);
    default input #1step output #1step;
    output reset, tx_en, tx_data_in, rx_data;
    input  tx_busy, tx_done, rx_done, parity_error, stop_error, frame_error;
  endclocking

  // Monitor clocking block
  clocking mon_cb @(posedge clk);
    default input #1step;
    input reset, tx_en, tx_data_in, tx_data, tx_busy, tx_done;
    input rx_data, rx_data_out, rx_done;
    input parity_error, stop_error, frame_error;
    input baud_tick, tick_16x;
  endclocking

  modport DRV (clocking drv_cb, input clk);
  modport MON (clocking mon_cb, input clk);
endinterface

`endif