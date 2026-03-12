// Forwarding Unit
// Detects data hazards and selects forwarding paths for ALU inputs.
//
// ForwardA/ForwardB encoding:
//   2'b00 = No forwarding (use register file value)
//   2'b10 = Forward from EX/MEM (previous instruction result)
//   2'b01 = Forward from MEM/WB (two instructions ago result)

module forwarding_unit (
    input  wire [4:0] id_ex_rs1,
    input  wire [4:0] id_ex_rs2,
    input  wire [4:0] ex_mem_rd,
    input  wire       ex_mem_reg_write,
    input  wire [4:0] mem_wb_rd,
    input  wire       mem_wb_reg_write,
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);
    always @(*) begin
        // Default: no forwarding
        forward_a = 2'b00;
        forward_b = 2'b00;

        // --- ForwardA (ALU input 1 / rs1) ---
        // EX Hazard: forward from EX/MEM
        if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;
        // MEM Hazard: forward from MEM/WB (only if EX hazard doesn't match)
        else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;

        // --- ForwardB (ALU input 2 / rs2) ---
        // EX Hazard: forward from EX/MEM
        if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;
        // MEM Hazard: forward from MEM/WB (only if EX hazard doesn't match)
        else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;
    end
endmodule
