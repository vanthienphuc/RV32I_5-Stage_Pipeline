`timescale 1ns / 1ps

module tb_RISCV_Pipeline;

    reg clk;
    reg rst_n;

    integer total_cycles;
    integer stall_cycles;
    integer actual_x7;

    // Instantiate the pipelined CPU
    RISCV_Pipeline dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_RISCV_Pipeline);

        // Load instruction and data memory
        $readmemh("./mem/imem.hex", dut.IMEM_inst.memory);
        $readmemh("./mem/dmem_init.hex", dut.DMEM_inst.memory);

        clk = 0;
        rst_n = 0;
        total_cycles = 0;
        stall_cycles = 0;

        #20;
        rst_n = 1;
    end

    // Monitor execution and report test results
    always @(posedge clk) begin
        if (rst_n) begin
            total_cycles = total_cycles + 1;

            if (dut.stall_load == 1'b1)
                stall_cycles = stall_cycles + 1;

            actual_x7 = dut.Reg_inst.registers[7];

            if (actual_x7 === 32'd1) begin
                $display("========================================");
                $display(" [PASSED] ALL PIPELINE TESTS PASSED!");
                $display(" - Data forwarding (ALU and Store)");
                $display(" - Load-use hazard (Stall and Bubble)");
                $display(" - JAL/JALR and Pipeline Flush");
                $display("----------------------------------------");
                $display(" REGRESSION REPORT:");
                $display(" - Total Cycles: %0d", total_cycles);
                $display(" - Load-use Stall Cycles: %0d", stall_cycles);
                $display("========================================");
                $finish;
            end
            else if (actual_x7 === 32'hFFFF_FFFF) begin
                $display("========================================");
                $display(" [FAILED] LOGIC OR TIMING ERROR!");
                $display(" CPU entered the 'fail' branch in test.S");
                $display(" Debug suggestions:");
                $display("   1. Check forwarding multiplexers");
                $display("   2. Check hazard detection and ID/EX bubble");
                $display("   3. Check branch resolution and IF/ID flush");
                $display(" Total Cycles Before Failure: %0d", total_cycles);
                $display("========================================");
                $finish;
            end

            // Stop simulation if it exceeds 2000 cycles
            if (total_cycles > 2000) begin
                $display("========================================");
                $display(" [TIMEOUT] Simulation exceeded %0d cycles!", total_cycles);
                $display("========================================");
                $finish;
            end
        end
    end

endmodule


