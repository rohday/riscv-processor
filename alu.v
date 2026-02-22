//   0000 -> AND
//   0001 -> OR
//   0010 -> ADD
//   0110 -> SUB

module alu (
    input  wire [63:0] input1,
    input  wire [63:0] input2,
    input  wire [3:0]  alu_control_signal,
    output reg  [63:0] alu_result,
    output wire        zero_flag
);
    always @(*) begin
        case (alu_control_signal)
            4'b0000: alu_result = input1 & input2;
            4'b0001: alu_result = input1 | input2;
            4'b0010: alu_result = input1 + input2;
            4'b0110: alu_result = input1 - input2;
            default: alu_result = 64'b0;
        endcase
    end

    assign zero_flag = (alu_result == 64'b0);
endmodule
