`define alu_ADD 4'b0000
`define alu_SUB 4'b0001
`define alu_AND 4'b0010
`define alu_OR  4'b0011
`define alu_XOR 4'b0100
`define alu_SLL 4'b0101
`define alu_SRL 4'b0110
`define alu_SRA 4'b0111
`define alu_SLT 4'b1000
`define alu_SLTU 4'b1001
`define alu_BEQ 4'b1010
`define alu_BGE 4'b1011
`define alu_BGEU 4'b1100
`define alu_BNE 4'b1101
`define alu_ADD_pc 4'b1110

module ALU #(parameter ROB_WIDTH = 4, parameter RS_WIDTH = 2)
            (input clk_in,
             input rst_in,
             input rdy_in,
             input clear,
             input cal,                 // 要计算为1
             input [31:0] a,
             input [31:0] b,
             input [3:0] alu_op,
             input [RS_WIDTH-1:0] from_rs_index,
             output reg to_rs,
             output reg [RS_WIDTH-1:0] to_rs_index,
             output reg [31:0] result);
    
    always @(posedge clk_in or negedge rst_in) begin
        if (rst_in | rdy_in & clear | !cal) begin
            to_rs <= 1'b0;
            end else begin
            to_rs <= 1'b1;
            to_rs_index <= from_rs_index;
            case (alu_op)
                `alu_ADD: result  <= a + b;
                `alu_SUB: result  <= a - b;
                `alu_AND: result  <= a & b;
                `alu_OR: result   <= a | b;
                `alu_XOR: result  <= a ^ b;
                `alu_SLL: result  <= a << b[4:0];
                `alu_SRL: result  <= a >> b[4:0];
                `alu_SRA: result  <= a >>> b[4:0];
                `alu_SLT: result  <= (a < b) ? 32'b1 : 32'b0;
                `alu_SLTU: result <= ($unsigned(a) < $unsigned(b)) ? 32'b1 : 32'b0;
                `alu_BEQ: result  <= (a == b)? 32'b1 : 32'b0;
                `alu_BGE: result  <= (a >= b)? 32'b1 : 32'b0;
                `alu_BGEU: result  <= ($unsigned(a) >= $unsigned(b))? 32'b1 : 32'b0;
                `alu_BNE: result  <= (a != b)? 32'b1 : 32'b0;
                `alu_ADD_pc: result <= a + b-32'd4;
            endcase
        end
    end
    
endmodule // ALU
