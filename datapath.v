`include "program_counter.v"
`include "instruction_memory.v"
`include "control_unit.v"
`include "register_file.v"
`include "immediate_gen.v"
`include "alu_control.v"
`include "alu.v"
`include "data_memory.v"

module datapath (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] instruction_word,
    output wire [63:0] pc_current
);
    //  Program Counter 
    wire [63:0] pc_next;
    wire [63:0] pc_plus4;

    program_counter PC (
        .clk    (clk),
        .reset  (reset),
        .pc_in  (pc_next),
        .pc_out (pc_current)
    );

    //  Instruction Memory 
    instruction_memory IMEM (
        .addr             (pc_current),
        .instruction_word (instruction_word)
    );

    //  Instruction fields 
    wire [6:0] opcode   = instruction_word[6:0];
    wire [4:0] rd       = instruction_word[11:7];
    wire [2:0] funct3   = instruction_word[14:12];
    wire [4:0] rs1      = instruction_word[19:15];
    wire [4:0] rs2      = instruction_word[24:20];
    wire       funct7_b = instruction_word[30];

    //  Control Unit 
    wire        branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write_en;
    wire [1:0]  alu_op;

    control_unit CU (
        .opcode      (opcode),
        .branch      (branch),
        .mem_read    (mem_read),
        .mem_to_reg  (mem_to_reg),
        .alu_op      (alu_op),
        .mem_write   (mem_write),
        .alu_src     (alu_src),
        .reg_write   (reg_write_en)
    );

    //  Register File 
    wire [63:0] reg_read_data1, reg_read_data2;
    wire [63:0] write_back_data;

    register_file REGFILE (
        .clk          (clk),
        .reset        (reset),
        .read_reg1    (rs1),
        .read_reg2    (rs2),
        .write_reg    (rd),
        .write_data   (write_back_data),
        .reg_write_en (reg_write_en),
        .read_data1   (reg_read_data1),
        .read_data2   (reg_read_data2)
    );

    //  Immediate Generator 
    wire [63:0] imm_extended;

    immediate_gen IMMGEN (
        .instruction_word (instruction_word),
        .imm_extended      (imm_extended)
    );

    //  ALU input MUX 
    wire [63:0] alu_input2 = alu_src ? imm_extended : reg_read_data2;

    //  ALU Control 
    wire [3:0] alu_control_signal;

    alu_control ALUCTRL (
        .alu_op             (alu_op),
        .funct7_bit30       (funct7_b),
        .funct3             (funct3),
        .alu_control_signal (alu_control_signal)
    );

    //  ALU 
    wire [63:0] alu_result;
    wire        zero_flag;

    alu ALU (
        .input1             (reg_read_data1),
        .input2             (alu_input2),
        .alu_control_signal (alu_control_signal),
        .alu_result         (alu_result),
        .zero_flag          (zero_flag)
    );

    //  Data Memory 
    wire [63:0] mem_read_data;

    data_memory DMEM (
        .clk        (clk),
        .reset      (reset),
        .address    (alu_result),
        .write_data (reg_read_data2),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .read_data  (mem_read_data)
    );

    //  Write-back MUX 
    assign write_back_data = mem_to_reg ? mem_read_data : alu_result;

    //  PC + 4 adder 
    assign pc_plus4 = pc_current + 64'd4;

    //  Branch target
    wire [63:0] branch_offset      = imm_extended << 1;
    wire [63:0] branch_target_addr = pc_current + branch_offset;

    //  PC select MUX 
    wire take_branch = branch & zero_flag;
    assign pc_next = take_branch ? branch_target_addr : pc_plus4;

endmodule
