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

    logic [1:0] wait_cnt;
    wire inserting_wait = valid_q && (wait_cnt < cfg_wait_states);

    assign HREADYOUT = !inserting_wait &&
                        !((do_write_req && fifo_full) || (do_read_req && fifo_empty));

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            wait_cnt <= '0;
        end else if (!valid_q) begin
            wait_cnt <= '0;
        end else if (HREADYOUT) begin
            wait_cnt <= '0;
        end else if (wait_cnt < cfg_wait_states) begin
            wait_cnt <= wait_cnt + 1'b1;
        end
    end

    wire do_write = do_write_req && !fifo_full  && !inserting_wait;
    wire do_read  = do_read_req  && !fifo_empty && !inserting_wait;

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
        end else if (HREADY) begin
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

    wire unused_ahb = |HADDR | |HSIZE | |HBURST;

endmodule
