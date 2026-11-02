module Program_Counter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,       
    input  wire [31:0] PC_in,
    output reg  [31:0] PC_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PC_out <= 32'b0;
        end else if (en) begin   // Only update the new PC when en = 1
            PC_out <= PC_in;
        end
        // If en = 0, PC_out will automatically retain its previous value (stall)
    end

endmodule

