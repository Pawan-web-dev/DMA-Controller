class dma_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(dma_scoreboard)

    //============================================================
    // Analysis port connection
    //============================================================
    uvm_analysis_imp #(dma_sequence_item, dma_scoreboard)
        item_collected_export;


    //============================================================
    // Constructor
    //============================================================
    function new(string name = "dma_scoreboard",
                 uvm_component parent = null);

        super.new(name, parent);

        item_collected_export =
            new("item_collected_export", this);

    endfunction


    //============================================================
    // Build phase
    //============================================================
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

    endfunction


    //============================================================
    // Receive transaction from monitor
    //============================================================
    function void write(dma_sequence_item item);

        `uvm_info(
            "DMA_SCB",
            $sformatf(
                "Received DMA transaction: SRC=0x%08h DST=0x%08h LEN=%0d ERROR=%0b CODE=%0d",
                item.src_addr,
                item.dst_addr,
                item.length_words,
                item.expected_error,
                item.expected_error_code
            ),
            UVM_MEDIUM
        );

        // Normal transfer
        if (!item.expected_error) begin

            if (item.expected_error_code == 4'h0) begin

                `uvm_info(
                    "DMA_SCB",
                    "DMA transfer completed successfully",
                    UVM_LOW
                );

            end
            else begin

                `uvm_error(
                    "DMA_SCB",
                    "Unexpected error code for successful DMA transfer"
                );

            end

        end

        // Error transfer
        else begin

            if (item.expected_error_code != 4'h0) begin

                `uvm_info(
                    "DMA_SCB",
                    $sformatf(
                        "DMA error correctly reported, code=%0d",
                        item.expected_error_code
                    ),
                    UVM_LOW
                );

            end
            else begin

                `uvm_error(
                    "DMA_SCB",
                    "DMA reported error without an error code"
                );

            end

        end

    endfunction

endclass