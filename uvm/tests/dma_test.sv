class dma_test extends uvm_test;

    `uvm_component_utils(dma_test)

    dma_env dma_env_h;

    function new(
        string name = "dma_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        dma_env_h = dma_env::type_id::create(
            "dma_env_h",
            this
        );

    endfunction

    task run_phase(uvm_phase phase);

        dma_sequence seq;

        phase.raise_objection(this);

        `uvm_info(
            "DMA_TEST",
            "Starting DMA UVM test",
            UVM_LOW
        )

        seq = dma_sequence::type_id::create("seq");

        seq.start(dma_env_h.dma_agent_h.sequencer);

        // Wait for the actual DMA result.
        wait (
            dma_env_h.dma_agent_h.driver.vif.done ||
            dma_env_h.dma_agent_h.driver.vif.error
        );

        #20;

        `uvm_info(
            "DMA_TEST",
            "DMA UVM test completed",
            UVM_LOW
        )

        phase.drop_objection(this);

    endtask

endclass