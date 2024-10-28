`define ADD 6'b000000
`define SUB 6'b000001
`define AND 6'b000010
`define OR  6'b000011
`define XOR 6'b000100
`define SLL 6'b000101
`define SRL 6'b000110
`define SRA 6'b000111
`define SLT 6'b001000
`define SLTU 6'b001001
`define ADDI 6'b001010
`define ANDI 6'b001011
`define ORI 6'b001100
`define XORI 6'b001101
`define SLLI 6'b001110
`define SRLI 6'b001111
`define SRAI 6'b010000
`define SLTI 6'b010001
`define SLTIU 6'b010010
`define BEQ 6'b011011
`define BGE 6'b011100
`define BGEU 6'b011101
`define BLT 6'b011110
`define BLTU 6'b011111
`define BNE 6'b100000
`define JAL 6'b100001
`define JALR 6'b100010
`define AUIPC 6'b100011
`define LUI 6'b100100
module rs#(parameter ROB_WIDTH = 4,
           parameter RS_SIZE = 8)
          (input rst_in,
           input clk_in,
           input rdy_in,
           input clear,
           input from_decoder,
           input [5:0]from_decoder_op,
           input [4:0]from_decoder_rd,
           input [4:0]from_decoder_rs1,
           input [4:0]from_decoder_rs2,
           input [31:0]from_decoder_imm,
           input [31:0]from_decoder_pc,
           input [ROB_WIDTH-1:0] from_decoder_tag,
           input from_reg_file,
           input [31:0] from_reg_file_rs1,
           input [31:0] from_reg_file_rs2,
           output reg [31:0] to_alu_a,
           output reg [31:0] to_alu_b,
           );
    
endmodule //rs
