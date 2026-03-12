// EX/MEM Pipeline Register
// Stores: ALU result, write data for store, rd, zero flag,
//         branch target, and control signals
// Supports flush to squash instructions on branch taken

module pipe_ex_mem (
    input  wire        clk,
    input  wire        reset,
    input  wire        ex_mem_flush,     // 1 = flush (squash instruction)

    // Data inputs
    input  wire [63:0] alu_result_in,
    input  wire [63:0] write_data_in,     // rs2 value (for sd)
    input  wire [4:0]  rd_in,
    input  wire        zero_flag_in,
    input  wire [63:0] branch_target_in,

    // Control signal inputs
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        branch_in,

    // Data outputs
    output reg  [63:0] alu_result_out,
    output reg  [63:0] write_data_out,
    output reg  [4:0]  rd_out,
    output reg         zero_flag_out,
    output reg  [63:0] branch_target_out,

    // Control signal outputs
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         branch_out
);
    always @(posedge clk or posedge reset) begin
        if (reset || ex_mem_flush) begin
            alu_result_out    <= 64'b0;
            write_data_out    <= 64'b0;
            rd_out            <= 5'b0;
            zero_flag_out     <= 1'b0;
            branch_target_out <= 64'b0;
            reg_write_out     <= 1'b0;
            mem_to_reg_out    <= 1'b0;
            mem_read_out      <= 1'b0;
            mem_write_out     <= 1'b0;
            branch_out        <= 1'b0;
        end else begin
            alu_result_out    <= alu_result_in;
            write_data_out    <= write_data_in;
            rd_out            <= rd_in;
            zero_flag_out     <= zero_flag_in;
            branch_target_out <= branch_target_in;
            reg_write_out     <= reg_write_in;
            mem_to_reg_out    <= mem_to_reg_in;
            mem_read_out      <= mem_read_in;
            mem_write_out     <= mem_write_in;
            branch_out        <= branch_in;
        end
    end
endmodule
