class dma_coverage extends uvm_subscriber #(dma_sequence_item);

    `uvm_component_utils(dma_coverage)

    dma_sequence_item cov_item;

    //============================================================
    // DMA Functional Coverage
    //============================================================
    covergroup dma_cg;

        option.per_instance = 1;

        //========================================================
        // Transfer length
        //========================================================
        cp_length: coverpoint cov_item.length_words {

            bins zero_length = {0};
            bins one_word    = {1};
            bins len_2_4     = {[2:4]};
            bins len_5_8     = {[5:8]};
            bins len_9_16    = {[9:16]};
        }

        //========================================================
        // IRQ enable
        //========================================================
        cp_irq: coverpoint cov_item.irq_enable {

            bins irq_disabled = {0};
            bins irq_enabled  = {1};
        }

        //========================================================
        // DMA result
        //========================================================
        cp_error: coverpoint cov_item.expected_error {

            bins success = {0};
            bins failure = {1};
        }

        //========================================================
        // Error code
        //========================================================
        cp_error_code: coverpoint cov_item.expected_error_code {

            bins no_error     = {0};
            bins zero_len_err = {1};
            bins align_err    = {2};
            bins read_err     = {3};
            bins write_err    = {4};
            bins other_err    = {5};
        }

        //========================================================
        // Source address alignment
        //========================================================
        cp_src_align: coverpoint cov_item.src_addr[1:0] {

            bins aligned   = {2'b00};
            bins unaligned = {[2'b01:2'b11]};
        }

        //========================================================
        // Destination address alignment
        //========================================================
        cp_dst_align: coverpoint cov_item.dst_addr[1:0] {

            bins aligned   = {2'b00};
            bins unaligned = {[2'b01:2'b11]};
        }

        //========================================================
        // Cross coverage
        //========================================================
        cross_length_error:
            cross cp_length, cp_error;

        cross_irq_error:
            cross cp_irq, cp_error;

        cross_src_dst_align:
            cross cp_src_align, cp_dst_align;

    endgroup


    //============================================================
    // Constructor
    //============================================================
    function new(
        string name = "dma_coverage",
        uvm_component parent = null
    );

        super.new(name, parent);

        dma_cg = new();

    endfunction


    //============================================================
    // Analysis write method
    //============================================================
    function void write(dma_sequence_item t);

        cov_item = t;

        dma_cg.sample();

        `uvm_info(
            "DMA_COV",
            "DMA functional coverage sampled",
            UVM_HIGH
        )

    endfunction

endclass