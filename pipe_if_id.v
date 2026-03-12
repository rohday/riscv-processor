// IF/ID Pipeline Register
// Stores: PC, Instruction
// Supports stall (if_id_write=0 holds values) and flush (zeros instruction)

module pipe_if_id (
    input  wire        clk,
    input  wire        reset,
    input  wire        if_id_write,  // 0 = stall (hold values)
    input  wire        if_id_flush,  // 1 = flush (insert NOP)
    input  wire [63:0] pc_in,
    input  wire [31:0] instruction_in,
    output reg  [63:0] pc_out,
    output reg  [31:0] instruction_out
);
    always @(posedge clk or posedge reset) begin
        if (reset || if_id_flush) begin
            pc_out          <= 64'b0;
            instruction_out <= 32'b0;  // NOP
        end else if (if_id_write) begin
            pc_out          <= pc_in;
            instruction_out <= instruction_in;
        end
        // If !if_id_write and !flush and !reset: hold current values (stall)
    end
endmodule
