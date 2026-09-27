class dma_monitor extends uvm_monitor;

    `uvm_component_utils(dma_monitor)

    //============================================================
    // Virtual interface
    //============================================================
    virtual dma_if vif;

    //============================================================
    // Analysis port
    //============================================================
    uvm_analysis_port #(dma_sequence_item) item_collected_port;


    //============================================================
    // Values captured from CSR writes
    //============================================================
    logic [31:0] src_addr;
    logic [31:0] dst_addr;
    logic [31:0] length_words;
    logic        irq_enable;

    logic transfer_reported;


    //============================================================
    // Constructor
    //============================================================
    function new(string name = "dma_monitor",
                 uvm_component parent = null);

        super.new(name, parent);

        item_collected_port =
            new("item_collected_port", this);

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
                "dma_monitor: virtual interface not found"
            )

        end

    endfunction


    //============================================================
    // Run phase
    //============================================================
    task run_phase(uvm_phase phase);

        dma_sequence_item item;

        forever begin

            @(posedge vif.clk);

            //====================================================
            // Capture CSR writes
            //====================================================
            if (vif.csr_valid && vif.csr_write) begin

                case (vif.csr_addr)

                    8'h08: begin
                        src_addr = vif.csr_wdata;

                        `uvm_info(
                            "DMA_MON",
                            $sformatf(
                                "SRC_ADDR = 0x%08h",
                                vif.csr_wdata
                            ),
                            UVM_HIGH
                        )
                    end

                    8'h0C: begin
                        dst_addr = vif.csr_wdata;

                        `uvm_info(
                            "DMA_MON",
                            $sformatf(
                                "DST_ADDR = 0x%08h",
                                vif.csr_wdata
                            ),
                            UVM_HIGH
                        )
                    end

                    8'h10: begin
                        length_words = vif.csr_wdata;

                        `uvm_info(
                            "DMA_MON",
                            $sformatf(
                                "LENGTH = %0d",
                                vif.csr_wdata
                            ),
                            UVM_HIGH
                        )
                    end

                    8'h14: begin
                        irq_enable = vif.csr_wdata[0];
                    end

                    // START
                    8'h00: begin

                        if (vif.csr_wdata[0]) begin
                            transfer_reported = 1'b0;

                            `uvm_info(
                                "DMA_MON",
                                "DMA START detected",
                                UVM_MEDIUM
                            )
                        end

                    end

                    default: begin
                    end

                endcase

            end


            //====================================================
            // Report successful completion
            //====================================================
            if (vif.done && !transfer_reported) begin

                item = dma_sequence_item::type_id::create(
                    "item",
                    this
                );

                item.src_addr      = src_addr;
                item.dst_addr      = dst_addr;
                item.length_words  = length_words;
                item.irq_enable    = irq_enable;

                item.expected_error      = 1'b0;
                item.expected_error_code = 4'h0;

                item_collected_port.write(item);

                transfer_reported = 1'b1;

                `uvm_info(
                    "DMA_MON",
                    $sformatf(
                        "DMA DONE: SRC=0x%08h DST=0x%08h LEN=%0d",
                        src_addr,
                        dst_addr,
                        length_words
                    ),
                    UVM_MEDIUM
                )

            end


            //====================================================
            // Report error
            //====================================================
            if (vif.error && !transfer_reported) begin

                item = dma_sequence_item::type_id::create(
                    "item",
                    this
                );

                item.src_addr      = src_addr;
                item.dst_addr      = dst_addr;
                item.length_words  = length_words;
                item.irq_enable    = irq_enable;

                item.expected_error      = 1'b1;
                item.expected_error_code = vif.error_code;

                item_collected_port.write(item);

                transfer_reported = 1'b1;

                `uvm_info(
                    "DMA_MON",
                    $sformatf(
                        "DMA ERROR: code=%0d",
                        vif.error_code
                    ),
                    UVM_MEDIUM
                )

            end

        end

    endtask

endclass