module program_counter (
    input  wire        clk,
    input  wire        reset,
    input  wire        pc_write,   // Enable signal (deassert to stall)
    input  wire [63:0] pc_in,
    output reg  [63:0] pc_out
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= 64'b0;
        else if (pc_write)
            pc_out <= pc_in;
    end
endmodule
