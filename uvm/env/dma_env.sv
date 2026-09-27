//=============================================================================
// Module      : dma_env
// Project     : RISC-V SoC with DMA Controller
//
// Description : DMA UVM environment.
//
// Contains:
//   - DMA agent
//   - DMA scoreboard
//   - DMA functional coverage
//
// Connections:
//   dma_monitor.item_collected_port
//           |
//           +------------------> dma_scoreboard.item_collected_export
//           |
//           +------------------> dma_coverage.analysis_export
//=============================================================================

class dma_env extends uvm_env;

    `uvm_component_utils(dma_env)

    //============================================================
    // DMA agent
    //============================================================
    dma_agent dma_agent_h;

    //============================================================
    // DMA scoreboard
    //============================================================
    dma_scoreboard dma_scoreboard_h;

    //============================================================
    // DMA functional coverage
    //============================================================
    dma_coverage dma_coverage_h;


    //============================================================
    // Constructor
    //============================================================
    function new(
        string name = "dma_env",
        uvm_component parent = null
    );

        super.new(name, parent);

    endfunction


    //============================================================
    // Build phase
    //============================================================
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        // Create DMA agent
        dma_agent_h = dma_agent::type_id::create(
            "dma_agent_h",
            this
        );

        // DMA agent is active because the driver configures
        // the DMA through the CSR interface.
        dma_agent_h.is_active = UVM_ACTIVE;

        // Create scoreboard
        dma_scoreboard_h = dma_scoreboard::type_id::create(
            "dma_scoreboard_h",
            this
        );

        // Create functional coverage
        dma_coverage_h = dma_coverage::type_id::create(
            "dma_coverage_h",
            this
        );

    endfunction


    //============================================================
    // Connect phase
    //============================================================
    function void connect_phase(uvm_phase phase);

        super.connect_phase(phase);

        // Monitor -> Scoreboard
        dma_agent_h.monitor.item_collected_port.connect(
            dma_scoreboard_h.item_collected_export
        );

        // Monitor -> Functional Coverage
        dma_agent_h.monitor.item_collected_port.connect(
            dma_coverage_h.analysis_export
        );

    endfunction


    //============================================================
    // End of elaboration
    //============================================================
    function void end_of_elaboration_phase(
        uvm_phase phase
    );

        super.end_of_elaboration_phase(phase);

        `uvm_info(
            "DMA_ENV",
            "DMA UVM environment constructed successfully",
            UVM_LOW
        )

    endfunction

endclass