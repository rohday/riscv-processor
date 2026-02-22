// Generates a 64-bit sign-extended immediate from a 32-bit instruction.

module immediate_gen (
    input  wire [31:0] instruction_word,
    output reg  [63:0] imm_extended
);
    wire [6:0] opcode = instruction_word[6:0];

    always @(*) begin
        case (opcode)
            7'b0010011, // addi
            7'b0000011: // ld
                imm_extended = {{52{instruction_word[31]}}, instruction_word[31:20]};

            7'b0100011: // sd
                imm_extended = {{52{instruction_word[31]}}, instruction_word[31:25], instruction_word[11:7]};

            7'b1100011: // beq
                imm_extended = {{52{instruction_word[31]}}, instruction_word[31], instruction_word[7],
                                 instruction_word[30:25], instruction_word[11:8]};

            default:
                imm_extended = 64'b0;
        endcase
    end
endmodule
