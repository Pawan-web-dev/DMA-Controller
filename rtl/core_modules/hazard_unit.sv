
module hazard_unit (
    input logic [4:0] rs1_E,
    input logic [4:0] rs2_E,

    input logic [4:0] rs1_D,
    input logic [4:0] rs2_D,

    input logic [4:0] rd_E,
    input logic [4:0] rd_M,
    input logic [4:0] rd_W,

    input logic Reg_write_M,
    input logic Reg_write_W,
    input logic PC_src_E,
    input logic Result_src0_E,
	
    output logic stallF,
    output logic stallD,

    output logic flushD,
    output logic flushE,

    output logic [1:0] forwardA_E,
    output logic [1:0] forwardB_E

);

    logic lwstall;

    always_comb begin
        //forwarding A
        if (((rs1_E==rd_M) && Reg_write_M) && (rs1_E!=0)) begin
            forwardA_E = 2'b10;
        end
        else if (((rs1_E==rd_W) && Reg_write_W) && (rs1_E!=0)) begin
            forwardA_E = 2'b01;
        end
        else begin
            forwardA_E = 2'b00;
        end
        //forwarding B
        if (((rs2_E==rd_M) && Reg_write_M) && (rs2_E!=0)) begin
            forwardB_E = 2'b10;
        end
        else if (((rs2_E==rd_W) && Reg_write_W) && (rs2_E!=0)) begin
            forwardB_E = 2'b01;
        end
        else begin
            forwardB_E = 2'b00;
        end

        //stalling
        lwstall = (Result_src0_E && ((rs1_D==rd_E)||(rs2_D==rd_E)));
        stallF = lwstall;
        stallD = lwstall;
        
        //flushing
        flushD = PC_src_E;
        flushE = lwstall||PC_src_E;
    end
endmodule