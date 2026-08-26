module top (
    input logic clk,
    input logic rst_n
);

    logic [31:0] pc_out;
    logic [31:0] pc_next;
    logic [31:0] PCPlus4;
    logic [31:0] PCTarget;
    logic [31:0] instruction;
    logic [31:0] immext;
    logic [31:0] Ra;
    logic [31:0] Rb;
    logic [31:0] src_A;
    logic [31:0] src_B;
    logic [31:0] ALU_out;
    logic        zero_f;
    logic [31:0] data_out;
    logic [31:0] ResultW;

    logic [1:0] ResultSrc;
    logic       MemWrite;
    logic       PCSrc, ALUSrc;
    logic       RegWrite, Jump;
    logic [1:0] ImmSrc;
    logic [2:0] ALUControl;

    controller c1(
        .op        (instruction[6:0]),
        .funct3    (instruction[14:12]),
        .funct7b5  (instruction[30]),
        .Zero      (zero_f),
        .ResultSrc (ResultSrc),
        .MemWrite  (MemWrite),
        .PCSrc     (PCSrc),
        .ALUSrc    (ALUSrc),
        .RegWrite  (RegWrite),
        .Jump      (Jump),
        .ImmSrc    (ImmSrc),
        .ALUControl(ALUControl)
    );

    PC pcreg(
        .clk    (clk),
        .rst_n  (rst_n),
        .pc_next(pc_next),
        .pc_out (pc_out)
    );

    adder_pc pcplus4(
        .A(pc_out),
        .B(32'd4),
        .Y(PCPlus4)
    );

    adder_pc pctarget(
        .A(pc_out),
        .B(immext),
        .Y(PCTarget)
    );

    assign pc_next = PCSrc ? PCTarget : PCPlus4;

    I_mem imem(
        .clk        (clk),
        .addr       (pc_out),
        .instruction(instruction)
    );

    reg_file rf(
        .clk (clk),
        .we  (RegWrite),
        .wd  (ResultW),
        .rs_1(instruction[19:15]),
        .rs_2(instruction[24:20]),
        .rd  (instruction[11:7]),
        .Ra  (Ra),
        .Rb  (Rb)
    );

    imm_extend ext(
        .instr (instruction[31:7]),
        .immsrc(ImmSrc),
        .immext(immext)
    );

    assign src_A = Ra;
    assign src_B = ALUSrc ? immext : Rb;

    ALU alu(
        .src_A     (src_A),
        .src_B     (src_B),
        .ALU_select(ALUControl),
        .ALU_out   (ALU_out),
        .zero_f    (zero_f)
    );

    D_mem dmem(
        .clk     (clk),
        .we      (MemWrite),
        .addr    (ALU_out),
        .wd      (Rb),
        .data_out(data_out)
    );

    mux_3to1 resultmux(
        .sel(ResultSrc),
        .A  (ALU_out),
        .B  (data_out),
        .C  (PCPlus4),
        .Y  (ResultW)
    );

endmodule