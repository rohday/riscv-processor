`include "pipe_datapath_ext.v"

module pipe_tb_extended;
    reg  clk;
    reg  reset;

    wire [31:0] instruction_word;
    wire [63:0] pc_current;

    pipe_datapath DUT (
        .clk                (clk),
        .reset              (reset),
        .instruction_word_out (instruction_word),
        .pc_current         (pc_current)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer cycle_count;
    integer fd;
    integer i;
    integer pass_count;
    integer fail_count;

    // VCD waveform dump
    initial begin
        $dumpfile("plots/pipeline_waveform.vcd");
        $dumpvars(0, pipe_tb_extended);
    end

    initial begin
        cycle_count = 0;
        pass_count = 0;
        fail_count = 0;
        reset = 1;
        @(posedge clk); #1;
        reset = 0;

        forever begin
            if (instruction_word == 32'h00000000) begin
                @(posedge clk); #1;

                $display("============================================");
                $display("  5-Stage Pipelined Processor Test Results");
                $display("============================================");
                $display("Total cycles: %0d", cycle_count);
                $display("");

                // Print register file
                $display("--- Register File ---");
                for (i = 0; i < 32; i = i + 1)
                    $display("x%0d = %016h", i, DUT.REGFILE.registers[i]);

                $display("");
                $display("--- Data Memory (selected addresses) ---");
                for (i = 0; i < 45; i = i + 1) begin
                    $display("mem[%0d] = %016h", i*8,
                        {DUT.DMEM.mem[i*8],   DUT.DMEM.mem[i*8+1],
                         DUT.DMEM.mem[i*8+2], DUT.DMEM.mem[i*8+3],
                         DUT.DMEM.mem[i*8+4], DUT.DMEM.mem[i*8+5],
                         DUT.DMEM.mem[i*8+6], DUT.DMEM.mem[i*8+7]});
                end

                $display("");
                $display("============================================");
                $display("  Automated Test Checks");
                $display("============================================");

                // Automatic correctness checks
                if (DUT.DMEM.mem[8]==8'h00 && DUT.DMEM.mem[15]==8'h05) pass_count = pass_count + 1; else fail_count = fail_count + 1;
                if (DUT.REGFILE.registers[0] == 64'h0) pass_count = pass_count + 1; else fail_count = fail_count + 1;
                if (DUT.REGFILE.registers[16] == 64'h5) pass_count = pass_count + 1; else fail_count = fail_count + 1;
                if (DUT.REGFILE.registers[18] == 64'h3e7) pass_count = pass_count + 1; else fail_count = fail_count + 1;
                if (DUT.REGFILE.registers[25] == 64'h2a) pass_count = pass_count + 1; else fail_count = fail_count + 1;
                if (DUT.REGFILE.registers[22] == 64'h0) pass_count = pass_count + 1; else fail_count = fail_count + 1;
                if (DUT.REGFILE.registers[20] == 64'hffe) pass_count = pass_count + 1; else fail_count = fail_count + 1;

                $display("\nTest Checks: %0d Passed, %0d Failed", pass_count, fail_count);
                $display("============================================");

                // Write register file to output
                fd = $fopen("register_file_extended.txt", "w");
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
