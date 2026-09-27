class dma_driver extends uvm_driver #(dma_sequence_item);

    `uvm_component_utils(dma_driver)

    //============================================================
    // Virtual interface
    //============================================================
    virtual dma_if vif;

    //============================================================
    // Simple memory model
    // 256 words = 1 KB
    //============================================================
    logic [31:0] mem_model [0:255];


    //============================================================
    // Constructor
    //============================================================
    function new(string name = "dma_driver",
                 uvm_component parent = null);

        super.new(name, parent);

    endfunction


    //============================================================
    // Build phase
    //============================================================
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db#(virtual dma_if)::get(
                this,
                "",
                "vif",
                vif)) begin

            `uvm_fatal(
                "NOVIF",
                "dma_driver: virtual interface not found"
            )

        end

    endfunction


    //============================================================
    // Run phase
    //============================================================
  task run_phase(uvm_phase phase);

    dma_sequence_item req;

    // Start the DMA memory responder
    start_memory_service();

    reset_dut();

    forever begin

        seq_item_port.get_next_item(req);

        `uvm_info(
            "DMA_DRV",
            $sformatf(
                "Driving DMA: SRC=0x%08h DST=0x%08h LEN=%0d IRQ=%0b",
                req.src_addr,
                req.dst_addr,
                req.length_words,
                req.irq_enable
            ),
            UVM_MEDIUM
        )

        prepare_memory(req);

        drive_csr_write(8'h08, req.src_addr);
        drive_csr_write(8'h0C, req.dst_addr);
        drive_csr_write(8'h10, req.length_words);
        drive_csr_write(8'h14, req.irq_enable);

        // START
        drive_csr_write(8'h00, 32'h00000001);

        seq_item_port.item_done();

    end

endtask

   


    //============================================================
    // Reset DUT
    //============================================================
    task reset_dut();

        vif.rst_n      = 1'b0;

        vif.csr_valid  = 1'b0;
        vif.csr_write  = 1'b0;
        vif.csr_addr   = 8'h00;
        vif.csr_wdata  = 32'h00000000;

        vif.mem_rdata  = 32'h00000000;
        vif.mem_ready  = 1'b0;
        vif.mem_error  = 1'b0;

        repeat (3)
            @(posedge vif.clk);

        vif.rst_n = 1'b1;

        repeat (2)
            @(posedge vif.clk);

        `uvm_info(
            "DMA_DRV",
            "DMA reset completed",
            UVM_MEDIUM
        )

    endtask


    //============================================================
    // CSR write
    //============================================================
    task drive_csr_write(
        input logic [7:0] addr,
        input logic [31:0] data
    );

        @(negedge vif.clk);

        vif.csr_valid = 1'b1;
        vif.csr_write = 1'b1;
        vif.csr_addr  = addr;
        vif.csr_wdata = data;

        @(negedge vif.clk);

        vif.csr_valid = 1'b0;
        vif.csr_write = 1'b0;
        vif.csr_addr  = 8'h00;
        vif.csr_wdata = 32'h00000000;

    endtask


    //============================================================
    // Prepare source memory
    //
    // Example:
    // SRC = 0x100
    // memory word 64 gets 0x11111111
    //============================================================
    task prepare_memory(
        dma_sequence_item req
    );

        int i;
        int src_index;

        src_index = req.src_addr >> 2;

        for (i = 0; i < req.length_words; i++) begin

            if ((src_index + i) < 256) begin

                mem_model[src_index + i] =
                    32'h11111111 + i;

            end

        end

        `uvm_info(
            "DMA_DRV",
            $sformatf(
                "Prepared %0d source words",
                req.length_words
            ),
            UVM_HIGH
        )

    endtask


    //============================================================
    // Memory responder
    //
    // This services DMA memory requests.
    //============================================================
    task memory_service();

        int index;

        forever begin

            @(negedge vif.clk);

            if (vif.mem_valid) begin

                index = vif.mem_addr >> 2;

                // Invalid address
                if ((vif.mem_addr[1:0] != 2'b00) ||
                    (index < 0) ||
                    (index >= 256)) begin

                    vif.mem_rdata = 32'h00000000;
                    vif.mem_ready = 1'b1;
                    vif.mem_error = 1'b1;

                end

                // READ
                else if (!vif.mem_write) begin

                    vif.mem_rdata = mem_model[index];
                    vif.mem_ready = 1'b1;
                    vif.mem_error = 1'b0;

                end

                // WRITE
                else begin

                    mem_model[index] = vif.mem_wdata;

                    vif.mem_rdata = 32'h00000000;
                    vif.mem_ready = 1'b1;
                    vif.mem_error = 1'b0;

                end

                @(negedge vif.clk);

                vif.mem_ready = 1'b0;
                vif.mem_error = 1'b0;
                vif.mem_rdata = 32'h00000000;

            end

        end

    endtask


    //============================================================
    // Start memory responder
    //============================================================
    task start_memory_service();

        fork
            memory_service();
        join_none

    endtask


endclass