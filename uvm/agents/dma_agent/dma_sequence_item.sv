

class dma_sequence_item extends uvm_sequence_item;

    //============================================================
    // DMA configuration
    //============================================================
    rand logic [31:0] src_addr;
    rand logic [31:0] dst_addr;
    rand logic [31:0] length_words;
    rand logic        irq_enable;

    //============================================================
    // Expected result
    //============================================================
    logic       expected_error;
    logic [3:0] expected_error_code;


    //============================================================
    // Constructor
    //============================================================
    function new(string name = "dma_sequence_item");
        super.new(name);
    endfunction


    //============================================================
    // Factory registration
    //============================================================
    `uvm_object_utils_begin(dma_sequence_item)

        `uvm_field_int(src_addr,            UVM_ALL_ON)
        `uvm_field_int(dst_addr,            UVM_ALL_ON)
        `uvm_field_int(length_words,        UVM_ALL_ON)
        `uvm_field_int(irq_enable,          UVM_ALL_ON)
        `uvm_field_int(expected_error,      UVM_ALL_ON)
        `uvm_field_int(expected_error_code, UVM_ALL_ON)

    `uvm_object_utils_end


    //============================================================
    // Constraints for normal DMA transfers
    //============================================================
    constraint aligned_addresses_c {
        src_addr[1:0] == 2'b00;
        dst_addr[1:0] == 2'b00;
    }

    constraint valid_length_c {
        length_words inside {[1:16]};
    }

endclass