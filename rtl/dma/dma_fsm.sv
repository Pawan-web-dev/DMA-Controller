//=============================================================================
// Module      : dma_fsm
// Project     : RISC-V SoC with DMA Controller
//
// Description : DMA transfer state machine.
//
// Transfer granularity:
//   32-bit words
//
// Addressing:
//   CPU/DMA addresses are BYTE addresses.
//   Addresses must therefore be 4-byte aligned.
//
// Memory interface:
//   mem_valid = 1 means DMA has an active request.
//   mem_write = 0 means READ.
//   mem_write = 1 means WRITE.
//   mem_ready = 1 means request completed.
//
// The interface supports memory wait states.
//=============================================================================

module dma_fsm (

    input  logic        clk,
    input  logic        rst_n,

    // Start/configuration
    input  logic        start,
    input  logic [31:0] cfg_src_addr,
    input  logic [31:0] cfg_dst_addr,
    input  logic [31:0] cfg_length_words,

    // Status
    output logic        busy,
    output logic        done_event,
    output logic        error_event,
    output logic [3:0]  error_code,

    // DMA memory master interface
    output logic        mem_valid,
    output logic        mem_write,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,

    input  logic [31:0] mem_rdata,
    input  logic        mem_ready,
    input  logic        mem_error
);


    //=========================================================================
    // FSM states
    //=========================================================================

    typedef enum logic [2:0] {

        S_IDLE  = 3'd0,
        S_READ  = 3'd1,
        S_WRITE = 3'd2,
        S_DONE  = 3'd3,
        S_ERROR = 3'd4

    } state_t;

    state_t state;


    //=========================================================================
    // Internal registers
    //=========================================================================

    logic [31:0] current_src;
    logic [31:0] current_dst;

    logic [31:0] remaining_words;

    logic [31:0] read_data;


    //=========================================================================
    // Sequential FSM
    //=========================================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state          <= S_IDLE;

            current_src   <= 32'h00000000;
            current_dst   <= 32'h00000000;
            remaining_words <= 32'h00000000;

            read_data      <= 32'h00000000;

            done_event     <= 1'b0;
            error_event    <= 1'b0;
            error_code     <= 4'h0;

        end
        else begin

            // Events are one-cycle pulses
            done_event  <= 1'b0;
            error_event <= 1'b0;

            case (state)

                //=============================================================
                // IDLE
                //=============================================================

                S_IDLE: begin

                    if (start) begin

                        current_src     <= cfg_src_addr;
                        current_dst     <= cfg_dst_addr;
                        remaining_words <= cfg_length_words;

                        // Check transfer length
                        if (cfg_length_words == 32'd0) begin

                            error_code  <= 4'h1;
                            error_event <= 1'b1;

                            state <= S_ERROR;

                        end

                        // Check source alignment
                        else if (cfg_src_addr[1:0] != 2'b00) begin

                            error_code  <= 4'h2;
                            error_event <= 1'b1;

                            state <= S_ERROR;

                        end

                        // Check destination alignment
                        else if (cfg_dst_addr[1:0] != 2'b00) begin

                            error_code  <= 4'h2;
                            error_event <= 1'b1;

                            state <= S_ERROR;

                        end

                        else begin

                            state <= S_READ;

                        end

                    end

                end


                //=============================================================
                // READ
                //=============================================================

                S_READ: begin

                    if (mem_error) begin

                        error_code  <= 4'h3;
                        error_event <= 1'b1;

                        state <= S_ERROR;

                    end

                    else if (mem_ready) begin

                        // Capture data returned by memory
                        read_data <= mem_rdata;

                        state <= S_WRITE;

                    end

                end


                //=============================================================
                // WRITE
                //=============================================================

                S_WRITE: begin

                    if (mem_error) begin

                        error_code  <= 4'h4;
                        error_event <= 1'b1;

                        state <= S_ERROR;

                    end

                    else if (mem_ready) begin

                        if (remaining_words == 32'd1) begin

                            remaining_words <= 32'd0;

                            state <= S_DONE;

                        end

                        else begin

                            remaining_words <= remaining_words - 32'd1;

                            current_src <= current_src + 32'd4;
                            current_dst <= current_dst + 32'd4;

                            state <= S_READ;

                        end

                    end

                end


                //=============================================================
                // DONE
                //=============================================================

                S_DONE: begin

                    done_event <= 1'b1;

                    state <= S_IDLE;

                end


                //=============================================================
                // ERROR
                //=============================================================

                S_ERROR: begin

                    state <= S_IDLE;

                end


                default: begin

                    state <= S_IDLE;

                end

            endcase

        end

    end


    //=========================================================================
    // Memory interface
    //=========================================================================

    always_comb begin

        mem_valid = 1'b0;
        mem_write = 1'b0;

        mem_addr  = 32'h00000000;
        mem_wdata = 32'h00000000;


        case (state)

            // READ REQUEST
            S_READ: begin

                mem_valid = 1'b1;
                mem_write = 1'b0;

                mem_addr  = current_src;

            end


            // WRITE REQUEST
            S_WRITE: begin

                mem_valid = 1'b1;
                mem_write = 1'b1;

                mem_addr  = current_dst;
                mem_wdata = read_data;

            end


            default: begin

            end

        endcase

    end


    //=========================================================================
    // BUSY
    //=========================================================================

    always_comb begin

        busy = (state == S_READ) ||
               (state == S_WRITE);

    end

endmodule