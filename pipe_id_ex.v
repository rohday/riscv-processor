// ID/EX Pipeline Register
// Stores: PC, register data, immediate, register addresses, funct fields, control signals
// Supports flush (zeros all control signals to create a bubble/NOP)

module pipe_id_ex (
    input  wire        clk,
    input  wire        reset,
    input  wire        id_ex_flush,  // 1 = insert bubble (zero control signals)

    // Data inputs
    input  wire [63:0] pc_in,
    input  wire [63:0] read_data1_in,
    input  wire [63:0] read_data2_in,
    input  wire [63:0] imm_extended_in,
    input  wire [4:0]  rs1_in,
    input  wire [4:0]  rs2_in,
    input  wire [4:0]  rd_in,
    input  wire [2:0]  funct3_in,
    input  wire        funct7_bit30_in,

    // Control signal inputs
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        alu_src_in,
    input  wire [1:0]  alu_op_in,
    input  wire        branch_in,

    // Data outputs
    output reg  [63:0] pc_out,
    output reg  [63:0] read_data1_out,
    output reg  [63:0] read_data2_out,
    output reg  [63:0] imm_extended_out,
    output reg  [4:0]  rs1_out,
    output reg  [4:0]  rs2_out,
    output reg  [4:0]  rd_out,
    output reg  [2:0]  funct3_out,
    output reg         funct7_bit30_out,

    // Control signal outputs
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         alu_src_out,
    output reg  [1:0]  alu_op_out,
    output reg         branch_out
);
    always @(posedge clk or posedge reset) begin
        if (reset || id_ex_flush) begin
            // Data — zero out
            pc_out            <= 64'b0;
            read_data1_out    <= 64'b0;
            read_data2_out    <= 64'b0;
            imm_extended_out  <= 64'b0;
            rs1_out           <= 5'b0;
            rs2_out           <= 5'b0;
            rd_out            <= 5'b0;
            funct3_out        <= 3'b0;
            funct7_bit30_out  <= 1'b0;
            // Control — zero (NOP/bubble)
            reg_write_out     <= 1'b0;
            mem_to_reg_out    <= 1'b0;
            mem_read_out      <= 1'b0;
            mem_write_out     <= 1'b0;
            alu_src_out       <= 1'b0;
            alu_op_out        <= 2'b0;
            branch_out        <= 1'b0;
        end else begin
            pc_out            <= pc_in;
            read_data1_out    <= read_data1_in;
            read_data2_out    <= read_data2_in;
            imm_extended_out  <= imm_extended_in;
            rs1_out           <= rs1_in;
            rs2_out           <= rs2_in;
            rd_out            <= rd_in;
            funct3_out        <= funct3_in;
            funct7_bit30_out  <= funct7_bit30_in;
            reg_write_out     <= reg_write_in;
            mem_to_reg_out    <= mem_to_reg_in;
            mem_read_out      <= mem_read_in;
            mem_write_out     <= mem_write_in;
            alu_src_out       <= alu_src_in;
            alu_op_out        <= alu_op_in;
            branch_out        <= branch_in;
        end
    end
endmodule
