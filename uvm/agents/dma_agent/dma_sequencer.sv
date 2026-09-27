

class dma_sequencer extends uvm_sequencer #(dma_sequence_item);

    `uvm_component_utils(dma_sequencer)

    function new(string name = "dma_sequencer",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass