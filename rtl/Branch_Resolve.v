module Branch_Resolve(
    input Is_Branch_E, Is_Jump_E, 
    input [2:0] funct3_E,         
    input BrEq_E, BrLt_E,         
    output reg PCSel_E            
);
    always @(*) begin
        if (Is_Jump_E) begin
            // JAL / JALR
            PCSel_E = 1'b1;
        end else if (Is_Branch_E) begin
            // Conditional branching instructions
            if (funct3_E[2]) begin
                // Instructions: BLT / BGE / BLTU / BGEU
                PCSel_E = BrLt_E ? ~funct3_E[0] : funct3_E[0];
            end else begin
                // Instructions: BEQ / BNE
                PCSel_E = BrEq_E ? ~funct3_E[0] : funct3_E[0];
            end
        end else begin
            // Mormal Instruction
            PCSel_E = 1'b0;
        end
    end
endmodule


