// Hazard Detection Unit
// Detects load-use hazards and signals a pipeline stall.
//
// Load-use hazard: instruction in EX is a load (MemRead=1) and its rd
// matches rs1 or rs2 of the instruction currently in ID.
//
// On stall:
//   - pc_write = 0       (hold PC)
//   - if_id_write = 0    (hold IF/ID)
//   - stall = 1          (insert bubble into ID/EX)

module hazard_detection_unit (
    input  wire       id_ex_mem_read,   // Is instruction in EX a load?
    input  wire [4:0] id_ex_rd,         // Destination register of EX instruction
    input  wire [4:0] if_id_rs1,        // Source register 1 of ID instruction
    input  wire [4:0] if_id_rs2,        // Source register 2 of ID instruction
    output reg        stall             // 1 = stall detected
);
    always @(*) begin
        if (id_ex_mem_read &&
            ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2)) &&
            (id_ex_rd != 5'b0))
        begin
            stall = 1'b1;
        end else begin
            stall = 1'b0;
        end
    end
endmodule
