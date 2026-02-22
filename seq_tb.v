`include "datapath.v"

module seq_tb;
    reg  clk;
    reg  reset;

    wire [31:0] instruction_word;
    wire [63:0] pc_current;

    datapath DUT (
        .clk              (clk),
        .reset            (reset),
        .instruction_word (instruction_word),
        .pc_current       (pc_current)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer cycle_count;
    integer fd;
    integer i;

    initial begin
        cycle_count = 0;
        reset = 1;
        @(posedge clk); #1;
        reset = 0;

        forever begin
            if (instruction_word == 32'h00000000) begin
                cycle_count = cycle_count + 1;
                @(posedge clk); #1;
                fd = $fopen("register_file.txt", "w");
                for (i = 0; i < 32; i = i + 1)
                    $fdisplay(fd, "%016h", DUT.REGFILE.registers[i]);
                $fdisplay(fd, "%0d", cycle_count);
                $fclose(fd);
                $finish;
            end
            cycle_count = cycle_count + 1;
            @(posedge clk); #1;
        end
    end
endmodule
