module ahb_master #(
    parameter int ADDR_WIDTH    = 32,
    parameter int DATA_WIDTH    = 32,
    parameter int MAX_BURST_LEN = 128,
    parameter int LEN_WIDTH     = $clog2(MAX_BURST_LEN + 1)
)(
    input  logic                  HCLK,
    input  logic                  HRESETn,
    input  logic                  HREADY,
    input  logic [DATA_WIDTH-1:0] HRDATA,
    input  logic                  HRESP,

    output logic [ADDR_WIDTH-1:0] HADDR,
    output logic [1:0]            HTRANS,
    output logic                  HWRITE,
    output logic [2:0]            HSIZE,
    output logic [2:0]            HBURST,
    output logic [DATA_WIDTH-1:0] HWDATA,

    input  logic                  req_start,
    input  logic                  req_write,
    input  logic [LEN_WIDTH-1:0]  req_burst_len,
    input  logic [ADDR_WIDTH-1:0] req_addr,

    output logic                  req_done
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_BURST0,
        ST_BURST,
        ST_ERR_COMP
    } state_e;

    localparam logic [1:0] HTRANS_IDLE   = 2'b00;
    localparam logic [1:0] HTRANS_NONSEQ = 2'b10;
    localparam logic [1:0] HTRANS_SEQ    = 2'b11;

    localparam logic [2:0] HSIZE_VAL =
        (DATA_WIDTH ==   8) ? 3'b000 :
        (DATA_WIDTH ==  16) ? 3'b001 :
        (DATA_WIDTH ==  32) ? 3'b010 :
        (DATA_WIDTH ==  64) ? 3'b011 :
        (DATA_WIDTH == 128) ? 3'b100 : 3'b010;

    localparam logic [ADDR_WIDTH-1:0] ADDR_INCR = DATA_WIDTH / 8;

    state_e               state;
    logic [LEN_WIDTH-1:0] beat_cnt;
    logic [LEN_WIDTH-1:0] active_burst_len;
    logic                 is_write;

    logic [DATA_WIDTH-1:0] wdata_buf [0:MAX_BURST_LEN-1];
    logic [DATA_WIDTH-1:0] rdata_buf [0:MAX_BURST_LEN-1];

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state            <= ST_IDLE;
            HADDR            <= '0;
            HTRANS           <= HTRANS_IDLE;
            HWRITE           <= 1'b0;
            HSIZE            <= HSIZE_VAL;
            HBURST           <= 3'b000;
            HWDATA           <= '0;
            req_done         <= 1'b0;
            beat_cnt         <= '0;
            active_burst_len <= '0;
            is_write         <= 1'b0;
        end else if (HREADY) begin
            unique case (state)

                ST_IDLE: begin
                    req_done <= 1'b0;
                    if (req_start && (req_burst_len > 0)) begin
                        HADDR            <= req_addr;
                        HWRITE           <= req_write;
                        HSIZE            <= HSIZE_VAL;
                        HTRANS           <= HTRANS_NONSEQ;
                        is_write         <= req_write;
                        active_burst_len <= req_burst_len;
                        beat_cnt         <= '0;
                        HBURST           <= (req_burst_len == 1) ? 3'b000 : 3'b001;
                        if (req_write)
                            HWDATA <= wdata_buf[0];
                        state <= ST_BURST0;
                    end else begin
                        HTRANS <= HTRANS_IDLE;
                    end
                end

                ST_BURST0: begin
                    if (HRESP) begin
                        HTRANS <= HTRANS_IDLE;
                        state  <= ST_ERR_COMP;
                    end else begin
                        if (active_burst_len > 1) begin
                            HTRANS <= HTRANS_SEQ;
                            HADDR  <= HADDR + ADDR_INCR;
                        end else begin
                            HTRANS <= HTRANS_IDLE;
                        end
                        state <= ST_BURST;
                    end
                end

                ST_BURST: begin
                    if (HRESP) begin
                        HTRANS <= HTRANS_IDLE;
                        state  <= ST_ERR_COMP;
                    end else if (!is_write) begin
                        rdata_buf[beat_cnt] <= HRDATA;

                        if (beat_cnt == (active_burst_len - 1'b1)) begin
                            HTRANS   <= HTRANS_IDLE;
                            req_done <= 1'b1;
                            state    <= ST_IDLE;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                            if ((beat_cnt + 2) < active_burst_len) begin
                                HTRANS <= HTRANS_SEQ;
                                HADDR  <= HADDR + ADDR_INCR;
                            end else begin
                                HTRANS <= HTRANS_IDLE;
                            end
                        end
                    end else begin
                        if (beat_cnt == (active_burst_len - 1'b1)) begin
                            HTRANS   <= HTRANS_IDLE;
                            req_done <= 1'b1;
                            state    <= ST_IDLE;
                        end else begin
                            beat_cnt <= beat_cnt + 1'b1;
                            HWDATA   <= wdata_buf[beat_cnt + 1'b1];
                            if ((beat_cnt + 2) < active_burst_len) begin
                                HTRANS <= HTRANS_SEQ;
                                HADDR  <= HADDR + ADDR_INCR;
                            end else begin
                                HTRANS <= HTRANS_IDLE;
                            end
                        end
                    end
                end

                ST_ERR_COMP: begin
                    HTRANS   <= HTRANS_IDLE;
                    req_done <= 1'b1;
                    state    <= ST_IDLE;
                end

                default: begin
                    HTRANS <= HTRANS_IDLE;
                    state  <= ST_IDLE;
                end
            endcase
        end
    end

endmodule


module ahb_slave #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int FIFO_DEPTH = 128
)(
    input  logic                  HCLK,
    input  logic                  HRESETn,
    input  logic                  HSEL,
    input  logic [ADDR_WIDTH-1:0] HADDR,
    input  logic [1:0]            HTRANS,
    input  logic                  HWRITE,
    input  logic [2:0]            HSIZE,
    input  logic [2:0]            HBURST,
    input  logic [DATA_WIDTH-1:0] HWDATA,
    input  logic                  HREADY,

    output logic [DATA_WIDTH-1:0] HRDATA,
    output logic                  HREADYOUT,
    output wire                   HRESP,

    input  logic [1:0]            cfg_wait_states
);

    localparam logic [1:0] HTRANS_NONSEQ = 2'b10;
    localparam logic [1:0] HTRANS_SEQ    = 2'b11;

    localparam int PTR_WIDTH = $clog2(FIFO_DEPTH);

    logic [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
    logic [PTR_WIDTH-1:0]  wr_ptr, rd_ptr;
    logic [PTR_WIDTH:0]    fifo_count;

    wire fifo_full  = (fifo_count == FIFO_DEPTH);
    wire fifo_empty = (fifo_count == 0);

    wire trans_valid = HSEL && ((HTRANS == HTRANS_NONSEQ) ||
                                (HTRANS == HTRANS_SEQ));

    logic write_q;
    logic valid_q;

    assign HRESP = 1'b0;

    wire do_write_req = valid_q &&  write_q;
    wire do_read_req  = valid_q && !write_q;

    assign HREADYOUT = !((do_write_req && fifo_full) || (do_read_req && fifo_empty));

    wire do_write = do_write_req && !fifo_full;
    wire do_read  = do_read_req  && !fifo_empty;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            write_q <= 1'b0;
            valid_q <= 1'b0;
        end else if (HREADY) begin
            write_q <= HWRITE;
            valid_q <= trans_valid;
        end
    end

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            wr_ptr     <= '0;
            rd_ptr     <= '0;
            fifo_count <= '0;
        end else begin
            if (do_write) begin
                fifo_mem[wr_ptr] <= HWDATA;
                wr_ptr           <= (wr_ptr == FIFO_DEPTH-1) ? '0 : (wr_ptr + 1'b1);
            end
            if (do_read) begin
                rd_ptr <= (rd_ptr == FIFO_DEPTH-1) ? '0 : (rd_ptr + 1'b1);
            end
            unique case ({do_write, do_read})
                2'b10:   fifo_count <= fifo_count + 1'b1;
                2'b01:   fifo_count <= fifo_count - 1'b1;
                default: ;
            endcase
        end
    end

    always_comb begin
        if (!fifo_empty)
            HRDATA = fifo_mem[rd_ptr];
        else
            HRDATA = '0;
    end

    wire unused_ahb = |HADDR | |HSIZE | |HBURST | |cfg_wait_states;

endmodule