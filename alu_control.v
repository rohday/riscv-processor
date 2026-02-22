//   00 -> ld/sd  : always ADD
//   01 -> beq    : always SUB
//   10 -> R-type / addi

//   0000 -> AND
//   0001 -> OR
//   0010 -> ADD
//   0110 -> SUB

module alu_control (
    input  wire [1:0] alu_op,
    input  wire       funct7_bit30,   // instruction[30]
    input  wire [2:0] funct3,         // instruction[14:12]
    output reg  [3:0] alu_control_signal
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_control_signal = 4'b0010; // ADD (ld/sd)
            2'b01: alu_control_signal = 4'b0110; // SUB (beq)
            2'b10: begin
                case (funct3)
                    3'b000: alu_control_signal = funct7_bit30 ? 4'b0110 : 4'b0010; // sub : add / addi
                    3'b111: alu_control_signal = 4'b0000; // and
                    3'b110: alu_control_signal = 4'b0001; // or
                    default: alu_control_signal = 4'b0010;
                endcase
            end
            default: alu_control_signal = 4'b0010;
        endcase
    end
endmodule
