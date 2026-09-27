class dma_sequence extends uvm_sequence #(dma_sequence_item);

    `uvm_object_utils(dma_sequence)

    function new(string name = "dma_sequence");
        super.new(name);
    endfunction

    task body();

        dma_sequence_item req;

        req = dma_sequence_item::type_id::create("req");

        start_item(req);

        req.src_addr      = 32'h00000100;
        req.dst_addr      = 32'h00000200;
        req.length_words  = 32'd4;
        req.irq_enable    = 1'b1;

        req.expected_error      = 1'b0;
        req.expected_error_code = 4'h0;

        finish_item(req);

    endtask

endclass