// MEM/WB Pipeline Register
// Stores: ALU result, memory read data, rd, and control signals

module pipe_mem_wb (
    input  wire        clk,
    input  wire        reset,

    // Data inputs
    input  wire [63:0] alu_result_in,
    input  wire [63:0] mem_read_data_in,
    input  wire [4:0]  rd_in,

    // Control signal inputs
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,

    // Data outputs
    output reg  [63:0] alu_result_out,
    output reg  [63:0] mem_read_data_out,
    output reg  [4:0]  rd_out,

    // Control signal outputs
    output reg         reg_write_out,
    output reg         mem_to_reg_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            alu_result_out    <= 64'b0;
            mem_read_data_out <= 64'b0;
            rd_out            <= 5'b0;
            reg_write_out     <= 1'b0;
            mem_to_reg_out    <= 1'b0;
        end else begin
            alu_result_out    <= alu_result_in;
            mem_read_data_out <= mem_read_data_in;
            rd_out            <= rd_in;
            reg_write_out     <= reg_write_in;
            mem_to_reg_out    <= mem_to_reg_in;
        end
    end
endmodule
