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
`define BEQ 4'b1010
`define BGE 4'b1011
`define BGEU 4'b1100
`define BNE 4'b1101
`define ADD_pc 4'b1110

module ALU #(parameter ROB_WIDTH = 4)
            (input clk_in,
             input rst_in,
             input rdy_in,
             input clear,
             input cal,                 // 要计算为1
             input [31:0] a,
             input [31:0] b,
             input [3:0] alu_op,
             output reg cal_out,
             output reg [31:0] result);
    
    always @(posedge clk_in or negedge rst_in) begin
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
                `SLT: result  <= (a < b) ? 32'b1 : 32'b0;
                `SLTU: result <= ($unsigned(a) < $unsigned(b)) ? 32'b1 : 32'b0;
                `BEQ: result  <= (a == b)? 32'b1 : 32'b0;
                `BGE: result  <= (a >= b)? 32'b1 : 32'b0;
                `BGEU: result  <= ($unsigned(a) >= $unsigned(b))? 32'b1 : 32'b0;
                `BNE: result  <= (a != b)? 32'b1 : 32'b0;
                `ADD_pc: result <= a + b-32'd4;
            endcase
        end
    end
    
endmodule // ALU
