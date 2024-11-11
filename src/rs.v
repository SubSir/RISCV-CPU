`define ADD_alu 4'b0000
`define SUB_alu 4'b0001
`define AND_alu 4'b0010
`define OR_alu  4'b0011
`define XOR_alu 4'b0100
`define SLL_alu 4'b0101
`define SRL_alu 4'b0110
`define SRA_alu 4'b0111
`define SLT_alu 4'b1000
`define SLTU_alu 4'b1001
`define BEQ_alu 4'b1010
`define BGE_alu 4'b1011
`define BGEU_alu 4'b1100
`define BNE_alu 4'b1101
`define ADD_alu_pc 4'b1110

`define WRITE_rob 3'b000
`define JUMP_rob 3'b001
`define BOTH_rob 3'b010
`define LS_rob 3'b011
`define NOTHING_rob 3'b100

`define LB_lsb 3'b000
`define LBU_lsb 3'b001
`define LH_lsb 3'b010
`define LHU_lsb 3'b011
`define LW_lsb 3'b100
`define SB_lsb 3'b101
`define SH_lsb 3'b110
`define SW_lsb 3'b111

module rs#(parameter ROB_WIDTH = 4,
           parameter RS_SIZE = 4,
           parameter RS_WIDTH = 2)
          (input rst_in,
           input clk_in,
           input rdy_in,
           input clear,
           input from_decoder,
           input [5:0] from_decoder_op,
           input [4:0] from_decoder_rd,
           input [4:0] from_decoder_rs1,
           input [4:0] from_decoder_rs2,
           input [31:0] from_decoder_imm,
           input [31:0] from_decoder_pc,
           input [ROB_WIDTH-1:0] from_decoder_tag,
           input from_reg_file_rs1_flag,
           input from_reg_file_rs2_flag,
           input [RS_WIDTH-1:0] from_reg_file_index,
           input [31:0] from_reg_file_rs1,
           input [31:0] from_reg_file_rs2,
           input from_alu,
           input [RS_WIDTH-1:0] from_alu_index,
           input [31:0] from_alu_result,
           input from_rob,
           input from_rob_update,
           input [ROB_WIDTH-1:0] from_rob_update_order,
           input [31:0] from_rob_update_wdata,
           output reg to_decoder,                     // 有剩余为 1
           output reg to_alu,
           output reg [RS_WIDTH-1:0] to_alu_index,
           output reg [31:0] to_alu_a,
           output reg [31:0] to_alu_b,
           output reg [3:0] to_alu_op,
           output reg to_reg_file_rs1_flag,
           output reg to_reg_file_rs2_flag,
           output reg [RS_WIDTH-1:0] to_reg_file_index,
           output reg [4:0] to_reg_file_rs1,
           output reg [4:0] to_reg_file_rs2,
           output reg to_rob,
           output reg [RS_WIDTH-1:0]to_rob_index,
           output reg [ROB_WIDTH-1:0] to_rob_tag,
           output reg [2:0] to_rob_op,
           output reg to_rob_ready,
           output reg [4:0] to_rob_rd,
           output reg [31:0] to_rob_wdata,
           output reg [31:0] to_rob_jump,
           output reg to_lsb,
           output reg [3:0]to_lsb_op,
           output reg [ROB_WIDTH-1:0]to_lsb_tag,
           output reg [31:0]to_lsb_wdata,
           output reg [31:0]to_lsb_address);
    
    reg busy [0:RS_SIZE-1];
    reg cal [0:RS_SIZE-1];
    reg [5:0] op [0:RS_SIZE-1];
    reg [2:0] op_rob [0:RS_SIZE-1];
    reg rob_ready [0:RS_SIZE-1];
    reg [3:0] op_lsb [0:RS_SIZE-1];
    reg [4:0] rd [0:RS_SIZE-1];
    reg vj_ready [0:RS_SIZE-1];
    reg [31:0] vj [0:RS_SIZE-1];
    reg [ROB_WIDTH-1:0] qj [0:RS_SIZE-1];
    reg vk_ready [0:RS_SIZE-1];
    reg [31:0] vk [0:RS_SIZE-1];
    reg [ROB_WIDTH-1:0] qk [0:RS_SIZE-1];
    reg [31:0] imm [0:RS_SIZE-1];
    reg [31:0] pc [0:RS_SIZE-1];
    reg alu_double[0:RS_SIZE-1]; // 0 单次 1 双次
    reg [ROB_WIDTH-1:0] rob_tag [0:RS_SIZE-1];
    reg reorder_busy [0:31];
    reg [ROB_WIDTH-1:0] reorder [0:31];
    reg [4:0] reg_file_rs1;
    reg [4:0] reg_file_rs2;
    reg [RS_WIDTH:0] busy_cnt;
    reg [RS_WIDTH:0] busy_cnt_tmp;
    integer i;
    reg rd_use;
    reg rs1_use;
    reg rs2_use;
    reg break;
    reg [4:0] update_rd;

    always @(posedge clk_in or posedge rst_in) begin
        if (rdy_in)begin
            if (rst_in || clear) begin
                for (i = 0; i < RS_SIZE; i = i + 1) begin
                    busy[i] <= 0;
                end
                to_rob      <= 0;
                to_alu      <= 0;
                to_reg_file_rs1_flag <= 0;
                to_reg_file_rs2_flag <= 0;
                to_decoder  <= 1;
                busy_cnt    <= 0;
                for (i=0; i < 32; i = i + 1) begin
                    reorder_busy[i] <= 0;
                end
                end else begin
                to_reg_file_rs1_flag <= 0;
                to_reg_file_rs2_flag <= 0;
                to_decoder <= (busy_cnt < RS_SIZE);
                if (from_rob_update) begin
                    for(i = 0; i < RS_SIZE; i = i + 1)begin
                        if (busy[i] && !vj_ready[i] && qj[i] == from_rob_update_order) begin
                            vj[i]    <= from_rob_update_wdata;
                            vj_ready[i] <= 1;
                        end
                        
                        if (busy[i] && !vk_ready[i] && qk[i] == from_rob_update_order) begin
                            vk[i]    <= from_rob_update_wdata;
                            vk_ready[i] <= 1;
                        end
                    end
                    for (i = 0; i < 32; i = i + 1) begin
                        if (reorder_busy[i] && reorder[i] == from_rob_update_order) begin
                            update_rd = i;
                            reorder_busy[i] <= 0;
                        end
                    end
                end
                
                busy_cnt_tmp = busy_cnt;
                if (from_decoder) begin
                    break = 0;
                    for (i = 0; i < RS_SIZE; i = i + 1) begin
                        if (!busy[i] && !break) begin
                            break = 1;
                            busy[i]     <= 1;
                            busy_cnt_tmp    = busy_cnt_tmp + 1;
                            cal[i]      <= 0;
                            rd[i]       <= from_decoder_rd;
                            rd_use  = 1;
                            rs1_use = 1;
                            rs2_use = 1; // 1 表示使用
                            vj_ready[i]   <= 0;
                            vk_ready[i]   <= 0;
                            alu_double[i] <= 0;
                            op_rob[i]     <= `WRITE_rob;
                            rob_tag[i]    <= from_decoder_tag;
                            op_lsb[i]     <= `LB_lsb;
                            pc[i]         <= from_decoder_pc;
                            if (from_decoder_op == `ADD) begin
                                $display("0 CLNT R1 index: %d, ADD, rd: %d, rs1: %d, rs2: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_rs2, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                end else if (from_decoder_op == `SUB) begin
                                $display("0 CLNT R1 index: %d, SUB, rd: %d, rs1: %d, rs2: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_rs2, from_decoder_pc);
                                op[i] <= `SUB_alu;
                                end else if (from_decoder_op == `AND) begin
                                $display("0 CLNT R1 index: %d, AND, rd: %d, rs1: %d, rs2: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_rs2, from_decoder_pc);
                                op[i] <= `AND_alu;
                                end else if (from_decoder_op == `OR) begin
                                $display("0 CLNT R1 index: %d, OR, rd: %d, rs1: %d, rs2: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_rs2, from_decoder_pc);
                                op[i] <= `OR_alu;
                                end else if (from_decoder_op == `XOR) begin
                                $display("0 CLNT R1 index: %d, XOR, rd: %d, rs1: %d, rs2: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_rs2, from_decoder_pc);
                                op[i] <= `XOR_alu;
                                end else if (from_decoder_op == `SLL) begin
                                $display("0 CLNT R1 index: %d, SLL, rd: %d, rs1: %d, rs2: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_rs2, from_decoder_pc);
                                op[i] <= `SLL_alu;
                                end else if (from_decoder_op == `SRL) begin
                                $display("0 CLNT R1 index: %d, SRL, rd: %d, rs1: %d, rs2: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_rs2, from_decoder_pc);
                                op[i] <= `SRL_alu;
                                end else if (from_decoder_op == `SRA) begin
                                $display("0 CLNT R1 index: %d, SRA, rd: %d, rs1: %d, rs2: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_rs2, from_decoder_pc);
                                op[i] <= `SRA_alu;
                                end else if (from_decoder_op == `SLT) begin
                                $display("0 CLNT R1 index: %d, SLT, rd: %d, rs1: %d, rs2: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_rs2, from_decoder_pc);
                                op[i] <= `SLT_alu;
                                end else if (from_decoder_op == `SLTU) begin
                                $display("0 CLNT R1 index: %d, SLTU, rd: %d, rs1: %d, rs2: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_rs2, from_decoder_pc);
                                op[i] <= `SLTU_alu;
                                end else if (from_decoder_op == `ADDI) begin
                                $display("0 CLNT R1 index: %d, ADDI, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `ANDI) begin
                                $display("0 CLNT R1 index: %d, ANDI, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `AND_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `ORI) begin
                                $display("0 CLNT R1 index: %d, ORI, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `OR_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `XORI) begin
                                $display("0 CLNT R1 index: %d, XORI, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `XOR_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `SLLI) begin
                                $display("0 CLNT R1 index: %d, SLLI, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `SLL_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `SRLI) begin
                                $display("0 CLNT R1 index: %d, SRLI, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `SRL_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `SRAI) begin
                                $display("0 CLNT R1 index: %d, SRAI, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `SRA_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `SLTI) begin
                                $display("0 CLNT R1 index: %d, SLTI, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `SLT_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `SLTIU) begin
                                $display("0 CLNT R1 index: %d, SLTIU, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `SLTU_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `LB) begin
                                $display("0 CLNT R1 index: %d, LB, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `LB_lsb;
                                rob_ready[i] <= 0;
                                end else if (from_decoder_op == `LBU) begin
                                $display("0 CLNT R1 index: %d, LBU, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `LBU_lsb;
                                rob_ready[i] <= 0;
                                end else if (from_decoder_op == `LH) begin
                                $display("0 CLNT R1 index: %d, LH, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `LH_lsb;
                                rob_ready[i] <= 0;
                                end else if (from_decoder_op == `LHU) begin
                                $display("0 CLNT R1 index: %d, LHU, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `LHU_lsb;
                                rob_ready[i] <= 0;
                                end else if (from_decoder_op == `LW) begin
                                $display("0 CLNT R1 index: %d, LW, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `LW_lsb;
                                rob_ready[i] <= 0;
                                end else if (from_decoder_op == `SB) begin
                                $display("0 CLNT R1 index: %d, SB, rs1: %d, imm: %d, pc: %h", i, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                rd_use = 0;
                                imm[i]    <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `SB_lsb;
                                rob_ready[i] <= 1;
                                end else if (from_decoder_op == `SH) begin
                                $display("0 CLNT R1 index: %d, SH, rs1: %d, imm: %d, pc: %h", i, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                rd_use = 0;
                                imm[i]    <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `SH_lsb;
                                rob_ready[i] <= 1;
                                end else if (from_decoder_op == `SW) begin
                                $display("0 CLNT R1 index: %d, SW, rs1: %d, imm: %d, pc: %h", i, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                rd_use = 0;
                                imm[i]    <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `SW_lsb;
                                rob_ready[i] <= 1;
                                end else if (from_decoder_op == `BEQ) begin
                                $display("0 CLNT R1 index: %d, BEQ, rs1: %d, rs2: %d, imm: %d, pc: %h", i, from_decoder_rs1, from_decoder_rs2, from_decoder_imm, from_decoder_pc);
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `BEQ_alu;
                                pc[i]         <= from_decoder_pc;
                                imm[i]    <= from_decoder_imm;
                                end else if (from_decoder_op == `BGE) begin
                                $display("0 CLNT R1 index: %d, BGE, rs1: %d, rs2: %d, imm: %d, pc: %h", i, from_decoder_rs1, from_decoder_rs2, from_decoder_imm, from_decoder_pc);
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `BGE_alu;
                                pc[i]         <= from_decoder_pc;
                                imm[i]    <= from_decoder_imm;
                                end else if (from_decoder_op == `BGEU) begin
                                $display("0 CLNT R1 index: %d, BGEU, rs1: %d, rs2: %d, imm: %d, pc: %h", i, from_decoder_rs1, from_decoder_rs2, from_decoder_imm, from_decoder_pc);
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `BGEU_alu;
                                pc[i]         <= from_decoder_pc;
                                imm[i]    <= from_decoder_imm;
                                end else if (from_decoder_op == `BLT) begin
                                $display("0 CLNT R1 index: %d, BLT, rs1: %d, rs2: %d, imm: %d, pc: %h", i, from_decoder_rs1, from_decoder_rs2, from_decoder_imm, from_decoder_pc);
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `SLT;
                                pc[i]         <= from_decoder_pc;
                                imm[i]    <= from_decoder_imm;
                                end else if (from_decoder_op == `BLTU) begin
                                $display("0 CLNT R1 index: %d, BLTU, rs1: %d, rs2: %d, imm: %d, pc: %h", i, from_decoder_rs1, from_decoder_rs2, from_decoder_imm, from_decoder_pc);
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `SLTU;
                                pc[i]         <= from_decoder_pc;
                                imm[i]    <= from_decoder_imm;
                                end else if (from_decoder_op == `BNE) begin
                                $display("0 CLNT R1 index: %d, BNE, rs1: %d, rs2: %d, imm: %d, pc: %h", i, from_decoder_rs1, from_decoder_rs2, from_decoder_imm, from_decoder_pc);
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `BNE_alu;
                                pc[i]         <= from_decoder_pc;
                                imm[i]    <= from_decoder_imm;
                                end else if (from_decoder_op == `JAL) begin
                                $display("0 CLNT R1 index: %d, JAL, rd: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_imm, from_decoder_pc);
                                rs1_use = 0;
                                rs2_use = 0;
                                vj[i]     <= from_decoder_pc;
                                vk[i]     <= from_decoder_imm;
                                op[i]     <= `ADD_alu_pc;
                                op_rob[i] <= `BOTH_rob;
                                end else if (from_decoder_op == `JALR) begin
                                $display("0 CLNT R1 index: %d, JALR, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op[i]     <= `ADD_alu_pc;
                                op_rob[i] <= `BOTH_rob;
                                end else if (from_decoder_op == `LUI)begin
                                $display("0 CLNT R1 index: %d, LUI, rd: %d, rs1: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `AUIPC)begin
                                $display("0 CLNT R1 index: %d, AUIPC, rd: %d, imm: %d, pc: %h", i, from_decoder_rd, from_decoder_rs1, from_decoder_imm, from_decoder_pc);
                                op[i] <= `ADD_alu_pc;
                                rs1_use = 0;
                                rs2_use = 0;
                                vj[i] <= from_decoder_pc;
                                vk[i] <= from_decoder_imm;
                            end
                            
                            if (rs1_use == 1) begin
                                vj_ready[i] <= 0;
                                if (from_rob_update && update_rd == from_decoder_rs1) begin
                                    vj[i] <= from_rob_update_wdata;
                                    vj_ready[i] <= 1;
                                    end else if (reorder_busy[from_decoder_rs1]) begin
                                    qj[i] <= reorder[from_decoder_rs1];
                                    end else begin
                                    to_reg_file_rs1_flag     <= 1;
                                    to_reg_file_index  <= i;
                                    to_reg_file_rs1 <= from_decoder_rs1;
                                end
                                end else begin
                                vj_ready[i]     <= 1;
                                to_reg_file_rs1_flag <= 0;
                            end
                            
                            if (rs2_use == 1) begin
                                vk_ready[i] <= 0;
                                if (from_rob_update && update_rd == from_decoder_rs2) begin
                                    vk[i] <= from_rob_update_wdata;
                                    vk_ready[i] <= 1;
                                    end else if (reorder_busy[from_decoder_rs2]) begin
                                    qk[i] <= reorder[from_decoder_rs2];
                                    end else begin
                                    to_reg_file_rs2_flag     <= 1;
                                    to_reg_file_index  <= i;
                                    to_reg_file_rs2 <= from_decoder_rs2;
                                end
                                end else begin
                                vk_ready[i]     <= 1;
                                to_reg_file_rs2_flag <= 0;
                            end
                            
                            if (rd_use == 1) begin
                                reorder_busy[from_decoder_rd] <= 1;
                                reorder[from_decoder_rd]      <= from_decoder_tag;
                            end
                        end
                    end
                end
            
                to_rob <= 0;
                to_lsb <= 0;
                if (from_alu) begin
                    if (alu_double[from_alu_index] == 0)begin
                        busy[from_alu_index] <= 0;
                        busy_cnt_tmp = busy_cnt_tmp - 1;
                        to_rob              <= 1;
                        to_rob_index        <= from_alu_index;
                        to_rob_tag          <= rob_tag[from_alu_index];
                        to_rob_op           <= op_rob[from_alu_index];
                        to_rob_rd           <= rd[from_alu_index];
                        if (op_rob[from_alu_index] == `WRITE_rob) begin
                            to_rob_wdata <= from_alu_result;
                            $display("0 SNAP R1 index: %d, WRITE tag: %d, rd: %d, wdata: %d", from_alu_index, rob_tag[from_alu_index], rd[from_alu_index], from_alu_result);
                            end else if (op_rob[from_alu_index] == `JUMP_rob) begin
                            to_rob_jump <= from_alu_result;
                            $display("0 SNAP R1 index: %d, JUMP tag: %d, jump: %h", from_alu_index, rob_tag[from_alu_index], from_alu_result);
                            end else if (op_rob[from_alu_index] == `BOTH_rob) begin
                            $display("0 SNAP R1 index: %d, BOTH tag: %d, rd: %d, wdata: %h, jump: %h", from_alu_index, rob_tag[from_alu_index], rd[from_alu_index], pc[from_alu_index], from_alu_result);
                            to_rob_wdata <= pc[from_alu_index];
                            to_rob_jump  <= from_alu_result;
                            end else if (op_rob[from_alu_index] == `LS_rob) begin
                            $display("0 SNAP R1 index: %d, LS tag: %d, address: %h, wdata: %d", from_alu_index, rob_tag[from_alu_index], from_alu_result, vk[from_alu_index]);
                            to_lsb         <= 1;
                            to_lsb_op      <= op_lsb[from_alu_index];
                            to_lsb_tag     <= rob_tag[from_alu_index];
                            to_lsb_address <= from_alu_result;
                            to_lsb_wdata   <= vk[from_alu_index];
                            to_rob_ready   <= rob_ready[from_alu_index];
                        end
                        end else begin
                        if (from_alu_result == 32'b1) begin
                            to_alu                <= 1;
                            alu_double[from_alu_index] <= 0;
                            to_alu_op             <= `ADD_alu_pc;
                            to_alu_a              <= imm[from_alu_index];
                            to_alu_b              <= pc[from_alu_index];
                            end else begin
                            busy[from_alu_index] <= 0;
                            busy_cnt_tmp = busy_cnt_tmp - 1;
                            to_rob              <= 1;
                            to_rob_index        <= from_alu_index;
                            to_rob_tag          <= rob_tag[from_alu_index];
                            to_rob_op           <= `NOTHING_rob;
                        end
                    end
                end

                busy_cnt <= busy_cnt_tmp;
                
                if (from_reg_file_rs1_flag)begin
                    vj_ready[from_reg_file_index] <= 1;
                    vj[from_reg_file_index]       <= from_reg_file_rs1;
                end

                if (from_reg_file_rs2_flag)begin
                    vk_ready[from_reg_file_index] <= 1;
                    vk[from_reg_file_index]       <= from_reg_file_rs2;
                end
                
                break = 0;
                to_alu <= 0;
                for(i = 0; i < RS_SIZE; i = i + 1) begin
                    if (!break && busy[i] && !cal[i] && vj_ready[i] && vk_ready[i]) begin
                        break = 1;
                        to_alu    <= 1;
                        to_alu_index <= i;
                        to_alu_a  <= vj[i];
                        if (op_lsb[i] == `SB_lsb || op_lsb[i] == `SH_lsb || op_lsb[i] == `SW_lsb)begin
                            to_alu_b <= imm[i];
                            end else begin
                            to_alu_b <= vk[i];
                        end
                        to_alu_op <= op[i];
                        cal[i]    <= 1; // 用作alu
                    end
                end
            end
        end
    end
endmodule //rs
