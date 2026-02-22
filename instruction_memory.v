`define IMEM_SIZE 4096

module instruction_memory (
    input  wire [63:0] addr,
    output wire [31:0] instruction_word
);
    reg [7:0] mem [0:`IMEM_SIZE-1];

    integer i;
    initial begin
        for (i = 0; i < `IMEM_SIZE; i = i + 1)
            mem[i] = 8'h00;
        $readmemh("instructions.txt", mem);
    end

    // Big-Endian
    assign instruction_word = {mem[addr], mem[addr+1], mem[addr+2], mem[addr+3]};
endmodule
