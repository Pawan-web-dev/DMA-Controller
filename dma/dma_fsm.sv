module dma_fsm (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [31:0] cfg_src_addr,
    input  logic [31:0] cfg_dst_addr,
    input  logic [31:0] cfg_length_words,
    output logic        busy,
    output logic        done_event,
    output logic        error_event,
    output logic [3:0]  error_code,
    output logic        mem_valid,
    output logic        mem_write,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    input  logic [31:0] mem_rdata,
    input  logic        mem_ready,
    input  logic        mem_error
);

    typedef enum logic [2:0] {
        S_IDLE  = 3'd0,
        S_READ  = 3'd1,
        S_WRITE = 3'd2,
        S_DONE  = 3'd3,
        S_ERROR = 3'd4
    } state_t;

    state_t state, state_n;

    logic [31:0] current_src, current_dst;
    logic [31:0] remaining_words;
    logic [31:0] read_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            current_src     <= 32'h0;
            current_dst     <= 32'h0;
            remaining_words <= 32'h0;
            read_data       <= 32'h0;
            done_event      <= 1'b0;
            error_event     <= 1'b0;
            error_code      <= 4'h0;
        end else begin
            done_event  <= 1'b0;
            error_event <= 1'b0;
            state       <= state_n;

            unique case (state)
                S_IDLE: begin
                    if (start) begin
                        current_src     <= cfg_src_addr;
                        current_dst     <= cfg_dst_addr;
                        remaining_words <= cfg_length_words;
                    end
                end
                S_READ: begin
                    if (mem_error) begin
                        error_code  <= 4'h3;
                        error_event <= 1'b1;
                    end else if (mem_ready) begin
                        read_data <= mem_rdata;
                    end
                end
                S_WRITE: begin
                    if (mem_error) begin
                        error_code  <= 4'h4;
                        error_event <= 1'b1;
                    end else if (mem_ready) begin
                        if (remaining_words != 32'd0)
                            remaining_words <= remaining_words - 32'd1;
                        if (remaining_words > 32'd1) begin
                            current_src <= current_src + 32'd4;
                            current_dst <= current_dst + 32'd4;
                        end
                    end
                end
                S_DONE: done_event <= 1'b1;
                default: ;
            endcase

            if (state == S_IDLE && start) begin
                if (cfg_length_words == 32'd0) begin
                    error_code  <= 4'h1;
                    error_event <= 1'b1;
                end else if ((cfg_src_addr[1:0] != 2'b00) || (cfg_dst_addr[1:0] != 2'b00)) begin
                    error_code  <= 4'h2;
                    error_event <= 1'b1;
                end
            end
        end
    end

    always_comb begin
        state_n = state;
        unique case (state)
            S_IDLE: begin
                if (start) begin
                    if (cfg_length_words == 32'd0)
                        state_n = S_ERROR;
                    else if ((cfg_src_addr[1:0] != 2'b00) || (cfg_dst_addr[1:0] != 2'b00))
                        state_n = S_ERROR;
                    else
                        state_n = S_READ;
                end
            end
            S_READ: begin
                if (mem_error)
                    state_n = S_ERROR;
                else if (mem_ready)
                    state_n = S_WRITE;
            end
            S_WRITE: begin
                if (mem_error)
                    state_n = S_ERROR;
                else if (mem_ready)
                    state_n = (remaining_words == 32'd1) ? S_DONE : S_READ;
            end
            S_DONE:  state_n = S_IDLE;
            S_ERROR: state_n = S_IDLE;
            default: state_n = S_IDLE;
        endcase
    end

    always_comb begin
        mem_valid = 1'b0;
        mem_write = 1'b0;
        mem_addr  = 32'h0;
        mem_wdata = 32'h0;

        unique case (state)
            S_READ: begin
                mem_valid = 1'b1;
                mem_write = 1'b0;
                mem_addr  = current_src;
            end
            S_WRITE: begin
                mem_valid = 1'b1;
                mem_write = 1'b1;
                mem_addr  = current_dst;
                mem_wdata = read_data;
            end
            default: ;
        endcase
    end

    assign busy = (state != S_IDLE);

endmodule
