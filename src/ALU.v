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
                `alu_ADD: begin
                    result  <= a + b;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: add result: %d", from_rs_index, a, b, a + b);
                end 
                `alu_SUB: begin
                    result  <= a - b;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: sub result: %d", from_rs_index, a, b, a - b);
                end
                `alu_AND: begin
                    result  <= a & b;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: and result: %d", from_rs_index, a, b, a & b);
                end
                `alu_OR: begin
                    result   <= a | b;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: or result: %d", from_rs_index, a, b, a | b);
                end
                `alu_XOR: begin
                    result  <= a ^ b;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: xor result: %d", from_rs_index, a, b, a ^ b);
                end
                `alu_SLL: begin
                    result  <= a << b[4:0];
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: sll result: %d", from_rs_index, a, b, a << b[4:0]);
                end
                `alu_SRL: begin
                    result  <= a >> b[4:0];
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: srl result: %d", from_rs_index, a, b, a >> b[4:0]);
                end
                `alu_SRA: begin
                    result  <= a >>> b[4:0];
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: sra result: %d", from_rs_index, a, b, a >>> b[4:0]);
                end
                `alu_SLT: begin
                    result  <= ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: slt result: %d", from_rs_index, a, b, (a < b) ? 32'b1 : 32'b0);
                end
                `alu_SLTU: begin
                    result <= ($unsigned(a) < $unsigned(b)) ? 32'b1 : 32'b0;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: sltu result: %d", from_rs_index, a, b, ($unsigned(a) < $unsigned(b)) ? 32'b1 : 32'b0);
                end
                `alu_BEQ: begin
                    result  <= (a == b)? 32'b1 : 32'b0;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: beq result: %d", from_rs_index, a, b, (a == b)? 32'b1 : 32'b0);
                end
                `alu_BGE: begin
                    result  <= ($signed(a) >= $signed(b))? 32'b1 : 32'b0;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: bge result: %d", from_rs_index, a, b, (a >= b)? 32'b1 : 32'b0);
                end
                `alu_BGEU: begin
                    result  <= ($unsigned(a) >= $unsigned(b))? 32'b1 : 32'b0;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: bgeu result: %d", from_rs_index, a, b, ($unsigned(a) >= $unsigned(b))? 32'b1 : 32'b0);
                end
                `alu_BNE: begin
                    result  <= (a != b)? 32'b1 : 32'b0;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: bne result: %d", from_rs_index, a, b, (a != b)? 32'b1 : 32'b0);
                end
                `alu_ADD_pc: begin
                    result <= a + b-32'd4;
                    // $display("0 LOG2 A5 index: %d, a: %d b: %d op: add_pc result: %h", from_rs_index, a, b, a + b-32'd4);
                end
            endcase
        end
    end
    
endmodule // ALU
