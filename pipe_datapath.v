`include "program_counter.v"
`include "instruction_memory.v"
`include "control_unit.v"
`include "register_file.v"
`include "immediate_gen.v"
`include "alu_control.v"
`include "alu.v"
`include "data_memory.v"
`include "pipe_if_id.v"
`include "pipe_id_ex.v"
`include "pipe_ex_mem.v"
`include "pipe_mem_wb.v"
`include "forwarding_unit.v"
`include "hazard_detection_unit.v"

module pipe_datapath (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] instruction_word_out,  // Current instruction in IF
    output wire [63:0] pc_current
);

    // =========================================================================
    //  Hazard / Control wires (declared early so they can be used everywhere)
    // =========================================================================
    wire        stall;            // From hazard detection unit
    wire        pc_write;         // ~stall
    wire        if_id_write;      // ~stall
    wire        id_ex_flush;      // stall OR branch flush
    wire        if_id_flush;      // branch flush
    wire        ex_mem_flush;     // branch flush (squash EX result)
    wire [1:0]  forward_a, forward_b;   // From forwarding unit

    // Branch taken signal (resolved at EX/MEM boundary)
    wire        branch_taken;

    // =========================================================================
    //  STAGE 1: INSTRUCTION FETCH (IF)
    // =========================================================================
    wire [63:0] pc_plus4;
    wire [31:0] if_instruction;
    wire [63:0] pc_next;

    program_counter PC (
        .clk      (clk),
        .reset    (reset),
        .pc_write (pc_write),
        .pc_in    (pc_next),
        .pc_out   (pc_current)
    );

    instruction_memory IMEM (
        .addr             (pc_current),
        .instruction_word (if_instruction)
    );

    assign pc_plus4 = pc_current + 64'd4;

    // PC MUX: select branch target or PC+4
    wire [63:0] ex_mem_branch_target;
    assign pc_next = branch_taken ? ex_mem_branch_target : pc_plus4;

    assign instruction_word_out = if_instruction;

    // =========================================================================
    //  IF/ID Pipeline Register
    // =========================================================================
    wire [63:0] if_id_pc;
    wire [31:0] if_id_instruction;

    pipe_if_id IF_ID (
        .clk             (clk),
        .reset           (reset),
        .if_id_write     (if_id_write),
        .if_id_flush     (if_id_flush),
        .pc_in           (pc_current),
        .instruction_in  (if_instruction),
        .pc_out          (if_id_pc),
        .instruction_out (if_id_instruction)
    );

    // =========================================================================
    //  STAGE 2: INSTRUCTION DECODE (ID)
    // =========================================================================

    // Instruction field extraction
    wire [6:0] id_opcode   = if_id_instruction[6:0];
    wire [4:0] id_rd       = if_id_instruction[11:7];
    wire [2:0] id_funct3   = if_id_instruction[14:12];
    wire [4:0] id_rs1      = if_id_instruction[19:15];
    wire [4:0] id_rs2      = if_id_instruction[24:20];
    wire       id_funct7_b = if_id_instruction[30];

    // Control Unit
    wire        id_branch, id_mem_read, id_mem_to_reg, id_mem_write, id_alu_src, id_reg_write;
    wire [1:0]  id_alu_op;

    control_unit CU (
        .opcode      (id_opcode),
        .branch      (id_branch),
        .mem_read    (id_mem_read),
        .mem_to_reg  (id_mem_to_reg),
        .alu_op      (id_alu_op),
        .mem_write   (id_mem_write),
        .alu_src     (id_alu_src),
        .reg_write   (id_reg_write)
    );

    // Register File
    wire [63:0] id_read_data1, id_read_data2;
    wire [63:0] wb_write_data;
    wire [4:0]  wb_rd;
    wire        wb_reg_write;

    register_file REGFILE (
        .clk          (clk),
        .reset        (reset),
        .read_reg1    (id_rs1),
        .read_reg2    (id_rs2),
        .write_reg    (wb_rd),
        .write_data   (wb_write_data),
        .reg_write_en (wb_reg_write),
        .read_data1   (id_read_data1),
        .read_data2   (id_read_data2)
    );

    // WB-to-ID Forwarding (handles the case when WB writes a register
    // that ID is simultaneously reading — register file can't handle this
    // in a single posedge because the write hasn't committed yet)
    wire [63:0] id_read_data1_fwd;
    wire [63:0] id_read_data2_fwd;

    assign id_read_data1_fwd = (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == id_rs1))
                               ? wb_write_data : id_read_data1;
    assign id_read_data2_fwd = (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == id_rs2))
                               ? wb_write_data : id_read_data2;

    // Immediate Generator
    wire [63:0] id_imm_extended;

    immediate_gen IMMGEN (
        .instruction_word (if_id_instruction),
        .imm_extended     (id_imm_extended)
    );

    // =========================================================================
    //  ID/EX Pipeline Register
    // =========================================================================
    wire [63:0] id_ex_pc;
    wire [63:0] id_ex_read_data1, id_ex_read_data2;
    wire [63:0] id_ex_imm_extended;
    wire [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;
    wire [2:0]  id_ex_funct3;
    wire        id_ex_funct7_bit30;
    wire        id_ex_reg_write, id_ex_mem_to_reg, id_ex_mem_read;
    wire        id_ex_mem_write, id_ex_alu_src, id_ex_branch;
    wire [1:0]  id_ex_alu_op;

    pipe_id_ex ID_EX (
        .clk              (clk),
        .reset            (reset),
        .id_ex_flush      (id_ex_flush),
        // Data in
        .pc_in            (if_id_pc),
        .read_data1_in    (id_read_data1_fwd),
        .read_data2_in    (id_read_data2_fwd),
        .imm_extended_in  (id_imm_extended),
        .rs1_in           (id_rs1),
        .rs2_in           (id_rs2),
        .rd_in            (id_rd),
        .funct3_in        (id_funct3),
        .funct7_bit30_in  (id_funct7_b),
        // Control in
        .reg_write_in     (id_reg_write),
        .mem_to_reg_in    (id_mem_to_reg),
        .mem_read_in      (id_mem_read),
        .mem_write_in     (id_mem_write),
        .alu_src_in       (id_alu_src),
        .alu_op_in        (id_alu_op),
        .branch_in        (id_branch),
        // Data out
        .pc_out           (id_ex_pc),
        .read_data1_out   (id_ex_read_data1),
        .read_data2_out   (id_ex_read_data2),
        .imm_extended_out (id_ex_imm_extended),
        .rs1_out          (id_ex_rs1),
        .rs2_out          (id_ex_rs2),
        .rd_out           (id_ex_rd),
        .funct3_out       (id_ex_funct3),
        .funct7_bit30_out (id_ex_funct7_bit30),
        // Control out
        .reg_write_out    (id_ex_reg_write),
        .mem_to_reg_out   (id_ex_mem_to_reg),
        .mem_read_out     (id_ex_mem_read),
        .mem_write_out    (id_ex_mem_write),
        .alu_src_out      (id_ex_alu_src),
        .alu_op_out       (id_ex_alu_op),
        .branch_out       (id_ex_branch)
    );

    // =========================================================================
    //  STAGE 3: EXECUTE (EX)
    // =========================================================================

    // Forwarding MUX for ALU input 1
    wire [63:0] ex_mem_alu_result;   // forward declared for forwarding
    reg  [63:0] alu_fwd_input1;
    always @(*) begin
        case (forward_a)
            2'b00: alu_fwd_input1 = id_ex_read_data1;           // No forwarding
            2'b10: alu_fwd_input1 = ex_mem_alu_result;           // From EX/MEM
            2'b01: alu_fwd_input1 = wb_write_data;               // From MEM/WB
            default: alu_fwd_input1 = id_ex_read_data1;
        endcase
    end

    // Forwarding MUX for ALU input 2 / store data
    reg  [63:0] alu_fwd_input2;
    always @(*) begin
        case (forward_b)
            2'b00: alu_fwd_input2 = id_ex_read_data2;           // No forwarding
            2'b10: alu_fwd_input2 = ex_mem_alu_result;           // From EX/MEM
            2'b01: alu_fwd_input2 = wb_write_data;               // From MEM/WB
            default: alu_fwd_input2 = id_ex_read_data2;
        endcase
    end

    // ALU src MUX: forwarded rs2 value or immediate
    wire [63:0] alu_input2 = id_ex_alu_src ? id_ex_imm_extended : alu_fwd_input2;

    // ALU Control
    wire [3:0] ex_alu_control_signal;

    alu_control ALUCTRL (
        .alu_op             (id_ex_alu_op),
        .funct7_bit30       (id_ex_funct7_bit30),
        .funct3             (id_ex_funct3),
        .alu_control_signal (ex_alu_control_signal)
    );

    // ALU
    wire [63:0] ex_alu_result;
    wire        ex_zero_flag;

    alu ALU (
        .input1             (alu_fwd_input1),
        .input2             (alu_input2),
        .alu_control_signal (ex_alu_control_signal),
        .alu_result         (ex_alu_result),
        .zero_flag          (ex_zero_flag)
    );

    // Branch target calculation
    wire [63:0] ex_branch_offset = id_ex_imm_extended << 1;
    wire [63:0] ex_branch_target = id_ex_pc + ex_branch_offset;

    // =========================================================================
    //  EX/MEM Pipeline Register
    // =========================================================================
    wire [63:0] ex_mem_write_data;
    wire [4:0]  ex_mem_rd;
    wire        ex_mem_zero_flag;
    wire        ex_mem_reg_write, ex_mem_mem_to_reg, ex_mem_mem_read;
    wire        ex_mem_mem_write, ex_mem_branch;

    pipe_ex_mem EX_MEM (
        .clk              (clk),
        .reset            (reset),
        .ex_mem_flush     (ex_mem_flush),
        // Data in
        .alu_result_in    (ex_alu_result),
        .write_data_in    (alu_fwd_input2),    // Forwarded rs2 value for store
        .rd_in            (id_ex_rd),
        .zero_flag_in     (ex_zero_flag),
        .branch_target_in (ex_branch_target),
        // Control in
        .reg_write_in     (id_ex_reg_write),
        .mem_to_reg_in    (id_ex_mem_to_reg),
        .mem_read_in      (id_ex_mem_read),
        .mem_write_in     (id_ex_mem_write),
        .branch_in        (id_ex_branch),
        // Data out
        .alu_result_out   (ex_mem_alu_result),
        .write_data_out   (ex_mem_write_data),
        .rd_out           (ex_mem_rd),
        .zero_flag_out    (ex_mem_zero_flag),
        .branch_target_out(ex_mem_branch_target),
        // Control out
        .reg_write_out    (ex_mem_reg_write),
        .mem_to_reg_out   (ex_mem_mem_to_reg),
        .mem_read_out     (ex_mem_mem_read),
        .mem_write_out    (ex_mem_mem_write),
        .branch_out       (ex_mem_branch)
    );

    // Branch resolution (from EX/MEM register outputs)
    assign branch_taken = ex_mem_branch & ex_mem_zero_flag;

    // =========================================================================
    //  STAGE 4: MEMORY (MEM)
    // =========================================================================
    wire [63:0] mem_read_data;

    data_memory DMEM (
        .clk        (clk),
        .reset      (reset),
        .address    (ex_mem_alu_result),
        .write_data (ex_mem_write_data),
        .mem_read   (ex_mem_mem_read),
        .mem_write  (ex_mem_mem_write),
        .read_data  (mem_read_data)
    );

    // =========================================================================
    //  MEM/WB Pipeline Register
    // =========================================================================
    wire [63:0] mem_wb_alu_result;
    wire [63:0] mem_wb_mem_read_data;
    wire        mem_wb_mem_to_reg;

    pipe_mem_wb MEM_WB (
        .clk               (clk),
        .reset              (reset),
        // Data in
        .alu_result_in      (ex_mem_alu_result),
        .mem_read_data_in   (mem_read_data),
        .rd_in              (ex_mem_rd),
        // Control in
        .reg_write_in       (ex_mem_reg_write),
        .mem_to_reg_in      (ex_mem_mem_to_reg),
        // Data out
        .alu_result_out     (mem_wb_alu_result),
        .mem_read_data_out  (mem_wb_mem_read_data),
        .rd_out             (wb_rd),
        // Control out
        .reg_write_out      (wb_reg_write),
        .mem_to_reg_out     (mem_wb_mem_to_reg)
    );

    // =========================================================================
    //  STAGE 5: WRITE BACK (WB)
    // =========================================================================
    assign wb_write_data = mem_wb_mem_to_reg ? mem_wb_mem_read_data : mem_wb_alu_result;

    // =========================================================================
    //  Forwarding Unit
    // =========================================================================
    forwarding_unit FWD (
        .id_ex_rs1        (id_ex_rs1),
        .id_ex_rs2        (id_ex_rs2),
        .ex_mem_rd        (ex_mem_rd),
        .ex_mem_reg_write (ex_mem_reg_write),
        .mem_wb_rd        (wb_rd),
        .mem_wb_reg_write (wb_reg_write),
        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );

    // =========================================================================
    //  Hazard Detection Unit
    // =========================================================================
    hazard_detection_unit HDU (
        .id_ex_mem_read (id_ex_mem_read),
        .id_ex_rd       (id_ex_rd),
        .if_id_rs1      (id_rs1),
        .if_id_rs2      (id_rs2),
        .stall          (stall)
    );

    // =========================================================================
    //  Hazard Control Signals
    // =========================================================================
    // Stall: hold PC and IF/ID, flush ID/EX
    assign pc_write    = ~stall;
    assign if_id_write = ~stall;

    // Flush on branch taken: flush IF/ID, ID/EX, and EX/MEM
    // (squash the 2 instructions fetched after the branch + the
    //  instruction that was in EX during the branch resolution cycle)
    assign if_id_flush  = branch_taken;
    assign id_ex_flush  = stall | branch_taken;
    assign ex_mem_flush = branch_taken;

endmodule
