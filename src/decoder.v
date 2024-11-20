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
`define LB 6'b010011
`define LBU 6'b010100
`define LH 6'b010101
`define LHU 6'b010110
`define LW 6'b010111
`define SB 6'b011000
`define SH 6'b011001
`define SW 6'b011010
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
`define NOTHING 6'b100101

module Decoder #(parameter ROB_WIDTH = 4, parameter ROB_SIZE = 16)
                (input rst_in,
                 input clk_in,
                 input rdy_in,
                 input clear,
                 input from_if,
                 input [31:0] pc,
                 input [31:0] instruction,
                 input from_rob,                       // rob 有剩余为1
                 input from_rs,                        // rs 有剩余为1
                 input from_lsb,                       // lsb 有剩余为1
                 output reg to_if,
                 output reg to_rs,
                 output reg [5:0]to_rs_op,
                 output reg [4:0] to_rs_rd,
                 output reg [4:0] to_rs_rs1,
                 output reg [4:0] to_rs_rs2,
                 output reg [31:0] to_rs_imm,
                 output reg [31:0] to_rs_pc,
                 output reg [ROB_WIDTH-1:0] to_rs_tag,
                 output reg to_lsb,
                 output reg [ROB_WIDTH-1:0]to_lsb_tag,
                 output reg to_rob);
    
    wire[6:0] func7  = instruction[31:25];
    wire[2:0] func3  = instruction[14:12];
    wire[6:0] opcode = instruction[6:0];
    wire[4:0] rd     = instruction[11:7];
    wire[4:0] rs1    = instruction[19:15];
    wire[4:0] rs2    = instruction[24:20];
    reg [ROB_WIDTH-1:0] rob_tag;
    always @(posedge clk_in or negedge rst_in) begin
        if (rdy_in) begin
            if (rst_in | clear | !from_if | !from_rob | !from_rs | !from_lsb) begin
                to_rs  <= 0;
                to_lsb <= 0;
                to_rob <= 0;
                if (rst_in || clear) begin
                    rob_tag <= 0;
                end
                if (from_rob && from_rs && from_lsb) begin
                    to_if <= 1;
                    end else begin
                    to_if <= 0;
                end
                end else begin
                to_rob <= 1;
                to_rs      <= 1;
                to_lsb     <= 0;
                to_rs_rd   <= rd;
                to_rs_rs1  <= rs1;
                to_rs_rs2  <= rs2;
                to_rs_tag  <= rob_tag;
                to_lsb_tag <= rob_tag;
                rob_tag <= rob_tag + 1;
                to_rs_pc   <= pc;
                if (opcode == 7'b0110011 && func3 == 3'b000 && func7 == 7'b0000000) begin
                    // ADD
                    to_rs_op <= `ADD;
                    // $display("0 LEAD D0 : ADD, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0110011 && func3 == 3'b000 && func7 == 7'b0100000) begin
                    // SUB
                    to_rs_op <= `SUB;
                    // $display("0 LEAD D0 : SUB, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0110011 && func3 == 3'b111 && func7 == 7'b0000000) begin
                    // AND
                    to_rs_op <= `AND;
                    // $display("0 LEAD D0 : AND, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0110011 && func3 == 3'b110 && func7 == 7'b0000000) begin
                    // OR
                    to_rs_op <= `OR;
                    // $display("0 LEAD D0 : OR, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0110011 && func3 == 3'b100 && func7 == 7'b0000000) begin
                    // XOR
                    to_rs_op <= `XOR;
                    // $display("0 LEAD D0 : XOR, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0110011 && func3 == 3'b001 && func7 == 7'b0000000) begin
                    // SLL
                    to_rs_op <= `SLL;
                    // $display("0 LEAD D0 : SLL, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0110011 && func3 == 3'b101 && func7 == 7'b0000000) begin
                    // SRL
                    to_rs_op <= `SRL;
                    // $display("0 LEAD D0 : SRL, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0110011 && func3 == 3'b101 && func7 == 7'b0100000) begin
                    // SRA
                    to_rs_op <= `SRA;
                    // $display("0 LEAD D0 : SRA, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0110011 && func3 == 3'b010 && func7 == 7'b0000000) begin
                    // SLT
                    to_rs_op <= `SLT;
                    // $display("0 LEAD D0 : SLT, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0110011 && func3 == 3'b011 && func7 == 7'b0000000) begin
                    // SLTU
                    to_rs_op <= `SLTU;
                    // $display("0 LEAD D0 : SLTU, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0010011 && func3 == 3'b000) begin
                    // ADDI
                    to_rs_op  <= `ADDI;
                    // $display("0 LEAD D0 : ADDI, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $signed(instruction[31:20]);
                    end else if (opcode == 7'b0010011 && func3 == 3'b111) begin
                    // ANDI
                    to_rs_op  <= `ANDI;
                    // $display("0 LEAD D0 : ANDI, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $signed(instruction[31:20]);
                    end else if (opcode == 7'b0010011 && func3 == 3'b110) begin
                    // ORI
                    to_rs_op  <= `ORI;
                    // $display("0 LEAD D0 : ORI, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $signed(instruction[31:20]);
                    end else if (opcode == 7'b0010011 && func3 == 3'b100) begin
                    // XORI
                    to_rs_op  <= `XORI;
                    // $display("0 LEAD D0 : XORI, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $signed(instruction[31:20]);
                    end else if (opcode == 7'b0010011 && func3 == 3'b001 && func7 == 7'b0000000) begin
                    // SLLI
                    to_rs_op  <= `SLLI;
                    // $display("0 LEAD D0 : SLLI, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $unsigned(instruction[24:20]);
                    end else if (opcode == 7'b0010011 && func3 == 3'b101 && func7 == 7'b0000000) begin
                    // SRLI
                    to_rs_op  <= `SRLI;
                    // $display("0 LEAD D0 : SRLI, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $unsigned(instruction[24:20]);
                    end else if (opcode == 7'b0010011 && func3 == 3'b101 && func7 == 7'b0100000) begin
                    // SRAI
                    to_rs_op  <= `SRAI;
                    // $display("0 LEAD D0 : SRAI, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $unsigned(instruction[24:20]);
                    end else if (opcode == 7'b0010011 && func3 == 3'b010) begin
                    // SLTI
                    to_rs_op  <= `SLTI;
                    // $display("0 LEAD D0 : SLTI, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $signed(instruction[31:20]);
                    end else if (opcode == 7'b0010011 && func3 == 3'b011) begin
                    // SLTIU
                    to_rs_op  <= `SLTIU;
                    // $display("0 LEAD D0 : SLTIU, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $unsigned(instruction[31:20]);
                    end else if (opcode == 7'b0000011 && func3 == 3'b000) begin
                    // LB
                    to_rs_op   <= `LB;
                    to_rs_imm  <= $signed(instruction[31:20]);
                    to_lsb     <= 1;
                    // $display("0 LEAD D0 : LB, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0000011 && func3 == 3'b100) begin
                    // LBU
                    to_rs_op   <= `LBU;
                    to_rs_imm  <= $signed(instruction[31:20]);
                    to_lsb     <= 1;
                    // $display("0 LEAD D0 : LBU, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0000011 && func3 == 3'b001) begin
                    // LH
                    to_rs_op   <= `LH;
                    to_rs_imm  <= $signed(instruction[31:20]);
                    to_lsb     <= 1;
                    // $display("0 LEAD D0 : LH, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0000011 && func3 == 3'b101) begin
                    // LHU
                    to_rs_op   <= `LHU;
                    to_rs_imm  <= $signed(instruction[31:20]);
                    to_lsb     <= 1;
                    // $display("0 LEAD D0 : LHU, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0000011 && func3 == 3'b010) begin
                    // LW
                    to_rs_op   <= `LW;
                    to_rs_imm  <= $signed(instruction[31:20]);
                    to_lsb     <= 1;
                    // $display("0 LEAD D0 : LW, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0100011 && func3 == 3'b000) begin
                    // SB
                    to_rs_op   <= `SB;
                    to_rs_imm  <= $signed({instruction[31:25], instruction[11:7]});
                    to_lsb     <= 1;
                    // $display("0 LEAD D0 : SB, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0100011 && func3 == 3'b001) begin
                    // SH
                    to_rs_op   <= `SH;
                    to_rs_imm  <= $signed({instruction[31:25], instruction[11:7]});
                    to_lsb     <= 1;
                    // $display("0 LEAD D0 : SH, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b0100011 && func3 == 3'b010) begin
                    // SW
                    to_rs_op   <= `SW;
                    to_rs_imm  <= $signed({instruction[31:25], instruction[11:7]});
                    to_lsb     <= 1;
                    // $display("0 LEAD D0 : SW, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b1100011 && func3 == 3'b000) begin
                    // BEQ
                    to_rs_op  <= `BEQ;
                    to_rs_imm <= $signed({instruction[31], instruction[7], instruction[30:25], instruction[11:8],1'b0});
                    // $display("0 LEAD D0 : BEQ, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b1100011 && func3 == 3'b101) begin
                    // BGE
                    to_rs_op  <= `BGE;
                    to_rs_imm <= $signed({instruction[31], instruction[7], instruction[30:25], instruction[11:8],1'b0});
                    // $display("0 LEAD D0 : BGE, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b1100011 && func3 == 3'b111) begin
                    // BGEU
                    to_rs_op  <= `BGEU;
                    to_rs_imm <= $signed({instruction[31], instruction[7], instruction[30:25], instruction[11:8],1'b0});
                    // $display("0 LEAD D0 : BGEU, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b1100011 && func3 == 3'b100) begin
                    // BLT
                    to_rs_op  <= `BLT;
                    to_rs_imm <= $signed({instruction[31], instruction[7], instruction[30:25], instruction[11:8],1'b0});
                    // $display("0 LEAD D0 : BLI, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b1100011 && func3 == 3'b110) begin
                    // BLTU
                    to_rs_op  <= `BLTU;
                    to_rs_imm <= $signed({instruction[31], instruction[7], instruction[30:25], instruction[11:8],1'b0});
                    // $display("0 LEAD D0 : BLTU, PC : %h, rob_tag : %d", pc, rob_tag);
                    end else if (opcode == 7'b1100011 && func3 == 3'b001) begin
                    // BNE
                    to_rs_op  <= `BNE;
                    // $display("0 LEAD D0 : BNE, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $signed({instruction[31], instruction[7], instruction[30:25], instruction[11:8],1'b0});
                    end else if (opcode == 7'b1100111 && func3 == 3'b000) begin
                    // JALR
                    to_rs_op  <= `JALR;
                    // $display("0 LEAD D0 : JALR, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $signed(instruction[31:20]);
                    end else if (opcode == 7'b1101111) begin
                    // JAL
                    to_rs_op  <= `JAL;
                    // $display("0 LEAD D0 : JAL, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_imm <= $signed({instruction[31], instruction[19:12],instruction[20],instruction[31:21],1'b0});
                    end else if (opcode == 7'b0010111) begin
                    // AUIPC
                    // $display("0 LEAD D0 : AUIPC, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_op  <= `AUIPC;
                    to_rs_imm <= {instruction[31:12], 12'b0};
                    end else if (opcode == 7'b0110111) begin
                    // LUI
                    // $display("0 LEAD D0 : LUI, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_op  <= `LUI;
                    to_rs_imm <= {instruction[31:12], 12'b0};
                    end else begin
                    // Illegal
                    // $display("0 LEAD D0 : ElSE, PC : %h, rob_tag : %d", pc, rob_tag);
                    to_rs_op <= `NOTHING;
                    end
            end
        end
    end
    
    
endmodule //Decoder
