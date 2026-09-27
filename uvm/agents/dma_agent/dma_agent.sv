class dma_agent extends uvm_agent;

    `uvm_component_utils(dma_agent)

    //============================================================
    // UVM components
    //============================================================
    dma_sequencer sequencer;
    dma_driver    driver;
    dma_monitor   monitor;


    //============================================================
    // Constructor
    //============================================================
    function new(string name = "dma_agent",
                 uvm_component parent = null);

        super.new(name, parent);

    endfunction


    //============================================================
    // Build phase
    //============================================================
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        monitor = dma_monitor::type_id::create(
            "monitor",
            this
        );

        if (is_active == UVM_ACTIVE) begin

            sequencer = dma_sequencer::type_id::create(
                "sequencer",
                this
            );

            driver = dma_driver::type_id::create(
                "driver",
                this
            );

        end

    endfunction


    //============================================================
    // Connect phase
    //============================================================
    function void connect_phase(uvm_phase phase);

        super.connect_phase(phase);

        if (is_active == UVM_ACTIVE) begin

            driver.seq_item_port.connect(
                sequencer.seq_item_export
            );

        end

    endfunction

endclass