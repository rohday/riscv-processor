// Data memory: 1024 bytes, Big-Endian byte addressed, 64-bit data bus.

module data_memory (
    input  wire        clk,
    input  wire        reset,
    input  wire [63:0] address,
    input  wire [63:0] write_data,
    input  wire        mem_read,
    input  wire        mem_write,
    output wire [63:0] read_data
);
    reg [7:0] mem [0:1023];

    wire [9:0] effective_addr = address[9:0];

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 8'h00;
    end

    // Synchronous write
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 1024; i = i + 1)
                mem[i] <= 8'h00;
        end else if (mem_write) begin
            mem[effective_addr]   <= write_data[63:56];
            mem[effective_addr+1] <= write_data[55:48];
            mem[effective_addr+2] <= write_data[47:40];
            mem[effective_addr+3] <= write_data[39:32];
            mem[effective_addr+4] <= write_data[31:24];
            mem[effective_addr+5] <= write_data[23:16];
            mem[effective_addr+6] <= write_data[15:8];
            mem[effective_addr+7] <= write_data[7:0];
        end
    end

    // Combinatorial read
    assign read_data = mem_read ?
        {mem[effective_addr],   mem[effective_addr+1],
         mem[effective_addr+2], mem[effective_addr+3],
         mem[effective_addr+4], mem[effective_addr+5],
         mem[effective_addr+6], mem[effective_addr+7]} : 64'b0;

endmodule
