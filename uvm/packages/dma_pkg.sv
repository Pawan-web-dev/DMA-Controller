package dma_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "../agents/dma_agent/dma_sequence_item.sv"
    `include "../agents/dma_agent/dma_sequencer.sv"
   `include "../agents/dma_agent/dma_driver.sv"
`include "../agents/dma_agent/dma_monitor.sv"
`include "../agents/dma_agent/dma_agent.sv"
 `include "../env/dma_scoreboard.sv"
 `include "../env/dma_env.sv"
`include "../agents/dma_agent/dma_sequence.sv"
    `include "../tests/dma_test.sv"


endpackage