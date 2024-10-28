`define ADD 4'b0000
`define SUB 4'b0001
`define AND 4'b0010
`define OR  4'b0011
`define XOR 4'b0100
`define SLL 4'b0101
`define SRL 4'b0110
`define SRA 4'b0111
`define SLT 4'b1000
`define SLTU 4'b1001

module ALU #(parameter ROB_WIDTH = 4)
            (input clk_in,
             input rst_in,
             input rdy_in,
             input clear,
             input cal,                // 要计算为1
             input [31:0] a,
             input [31:0] b,
             input [3:0] alu_op,
             output reg cal_out,
             output reg [31:0] result,
             );
    
    always @(posedge clk or negedge reset) begin
        if (rst_in | rdy_in & clear | !cal) begin
            cal_out <= 0;
            end else begin
            case (alu_op)
                `ADD: result  <= a + b;
                `SUB: result  <= a - b;
                `AND: result  <= a & b;
                `OR: result   <= a | b;
                `XOR: result  <= a ^ b;
                `SLL: result  <= a << b[4:0];
                `SRL: result  <= a >> b[4:0];
                `SRA: result  <= a >>> b[4:0];
                `SLT: result  <= a < b;
                `SLTU: result <= $unsigned(a) < $unsigned(b);
            endcase
        end
    end
    
endmodule // ALU
