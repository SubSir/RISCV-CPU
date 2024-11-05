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
           input from_reg_file,
           input [31:0] from_reg_file_rs1,
           input [31:0] from_reg_file_rs2,
           input [31:0] from_alu_result,
           input from_rob,
           input from_rob_update,
           input [RS_WIDTH-1:0] from_rob_update_order,
           input [31:0] from_rob_update_wdata,
           output reg to_decoder,                     // 有剩余为 1
           output reg to_alu,
           output reg [31:0] to_alu_a,
           output reg [31:0] to_alu_b,
           output reg [3:0] to_alu_op,
           output reg to_reg_file,
           output reg [4:0] to_reg_file_rs1,
           output reg [4:0] to_reg_file_rs2,
           output reg to_rob,
           output reg [RS_WIDTH-1:0]to_rob_index,
           output reg [ROB_WIDTH-1:0] to_rob_tag,
           output reg [2:0] to_rob_op,
           output reg [4:0] to_rob_rd,
           output reg [31:0] to_rob_wdata,
           output reg [31:0] to_rob_jump,
           output reg to_lsb,
           output reg [3:0]to_lsb_op,
           output reg [4:0]to_lsb_rd,
           output reg [31:0]to_lsb_wdata,
           output reg [31:0]to_lsb_address);
    
    reg busy [0:RS_SIZE-1];
    reg cal [0:RS_SIZE-1];
    reg commited [0:RS_SIZE-1];
    reg [5:0] op [0:RS_SIZE-1];
    reg [2:0] op_rob [0:RS_SIZE-1];
    reg [3:0] op_lsb [0:RS_SIZE-1];
    reg [4:0] rd [0:RS_SIZE-1];
    reg vj_ready [0:RS_SIZE-1];
    reg [31:0] vj [0:RS_SIZE-1];
    reg [4:0] qj [0:RS_SIZE-1];
    reg vk_ready [0:RS_SIZE-1];
    reg [31:0] vk [0:RS_SIZE-1];
    reg [4:0] qk [0:RS_SIZE-1];
    reg [31:0] imm [0:RS_SIZE-1];
    reg [31:0] pc [0:RS_SIZE-1];
    reg alu_double[0:RS_SIZE-1]; // 0 单次 1 双次
    reg [ROB_WIDTH-1:0] rob_tag [0:RS_SIZE-1];
    reg  reorder_busy [0:31];
    reg [4:0] reorder [0:31];
    reg [RS_WIDTH-1:0] alu_index;
    reg [RS_WIDTH-1:0] reg_file_index;
    reg [4:0] reg_file_rs1;
    reg [4:0] reg_file_rs2;
    reg [RS_WIDTH-1:0] busy_cnt;
    reg [RS_WIDTH-1:0] i;
    reg found;
    reg rd_use;
    reg rs1_use;
    reg rs2_use;

    always @(posedge clk_in or posedge rst_in) begin
        if (rdy_in)begin
            if (rst_in || clear) begin
                for (i = 0; i < RS_SIZE; i++) begin
                    busy[i] <= 0;
                end
                to_rob      <= 0;
                to_alu      <= 0;
                to_reg_file <= 0;
                to_decoder  <= 1;
                busy_cnt    <= 0;
                end else begin
                to_decoder <= (busy_cnt > 0);
                if (from_rob_update) begin
                    for(i = 0; i < RS_SIZE; i++)begin
                        if (busy[i] && qj[i] == from_rob_update_order)begin
                            vj[i]    <= from_rob_update_wdata;
                            vj_ready[i] <= 1;
                        end
                        
                        if (busy[i] && qk[i] == from_rob_update_order)begin
                            vk[i]    <= from_rob_update_wdata;
                            vk_ready[i] <= 1;
                        end
                    end
                    busy[from_rob_update_order]             <= 0;
                    reorder_busy[rd[from_rob_update_order]] <= 0;
                end
                
                
                if (from_decoder) begin
                    found = 0;
                    for (i = 0; i < RS_SIZE; i++) begin
                        if (!busy[i] && !found) begin
                            found = 1;
                            busy[i]     <= 1;
                            busy_cnt    <= busy_cnt + 1;
                            cal[i]      <= 0;
                            commited[i] <= 0;
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
                            if (from_decoder_op == `ADD) begin
                                op[i] <= `ADD_alu;
                                end else if (from_decoder_op == `SUB) begin
                                op[i] <= `SUB_alu;
                                end else if (from_decoder_op == `AND) begin
                                op[i] <= `AND_alu;
                                end else if (from_decoder_op == `OR) begin
                                op[i] <= `OR_alu;
                                end else if (from_decoder_op == `XOR) begin
                                op[i] <= `XOR_alu;
                                end else if (from_decoder_op == `SLL) begin
                                op[i] <= `SLL_alu;
                                end else if (from_decoder_op == `SRL) begin
                                op[i] <= `SRL_alu;
                                end else if (from_decoder_op == `SRA) begin
                                op[i] <= `SRA_alu;
                                end else if (from_decoder_op == `SLT) begin
                                op[i] <= `SLT_alu;
                                end else if (from_decoder_op == `SLTU) begin
                                op[i] <= `SLTU_alu;
                                end else if (from_decoder_op == `ADDI) begin
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `ANDI) begin
                                op[i] <= `AND_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `ORI) begin
                                op[i] <= `OR_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `XORI) begin
                                op[i] <= `XOR_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == ``SLLI) begin
                                op[i] <= `SLL_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `SRLI) begin
                                op[i] <= `SRL_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `SRAI) begin
                                op[i] <= `SRA_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `SLTI) begin
                                op[i] <= `SLT_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `SLTIU) begin
                                op[i] <= `SLTU_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `LB) begin
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `LB_lsb;
                                end else if (from_decoder_op == `LBU) begin
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `LBU_lsb;
                                end else if (from_decoder_op == `LH) begin
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `LH_lsb;
                                end else if (from_decoder_op == `LHU) begin
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `LHU_lsb;
                                end else if (from_decoder_op == `LW) begin
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `LW_lsb;
                                end else if (from_decoder_op == `SB) begin
                                op[i] <= `ADD_alu;
                                rd_use = 0;
                                imm[i]    <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `SB_lsb;
                                end else if (from_decoder_op == `SH) begin
                                op[i] <= `ADD_alu;
                                rd_use = 0;
                                imm[i]    <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `SH_lsb;
                                end else if (from_decoder_op == `SW) begin
                                op[i] <= `ADD_alu;
                                rd_use = 0;
                                imm[i]    <= from_decoder_imm;
                                op_rob[i] <= `LS_rob;
                                op_lsb[i] <= `SW_lsb;
                                end else if (from_decoder_op == `BEQ) begin
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `BEQ_alu;
                                pc[i]         <= from_decoder_pc;
                                end else if (from_decoder_op == `BGE) begin
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `BGE_alu;
                                pc[i]         <= from_decoder_pc;
                                end else if (from_decoder_op == `BGEU) begin
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `BGEU_alu;
                                pc[i]         <= from_decoder_pc;
                                end else if (from_decoder_op == `BLT) begin
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `SLT;
                                pc[i]         <= from_decoder_pc;
                                end else if (from_decoder_op == `BLTU) begin
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `SLTU;
                                pc[i]         <= from_decoder_pc;
                                end else if (from_decoder_op == `BNE) begin
                                rd_use = 0;
                                alu_double[i] <= 1;
                                op_rob[i]     <= `JUMP_rob;
                                op[i]         <= `BNE_alu;
                                pc[i]         <= from_decoder_pc;
                                end else if (from_decoder_op == `JAL) begin
                                rs1_use = 0;
                                rs2_use = 0;
                                vj[i]     <= from_decoder_pc;
                                vk[i]     <= from_decoder_imm;
                                op[i]     <= `ADD_alu_pc;
                                op_rob[i] <= `BOTH_rob;
                                end else if (from_decoder_op == `JALR) begin
                                rs2_use = 0;
                                vk[i]     <= from_decoder_imm;
                                op[i]     <= `ADD_alu_pc;
                                op_rob[i] <= `BOTH_rob;
                                end else if (from_decoder_op == `LUI)begin
                                op[i] <= `ADD_alu;
                                rs2_use = 0;
                                vk[i] <= from_decoder_imm;
                                end else if (from_decoder_op == `AUIPC)begin
                                op[i] <= `ADD_alu_pc;
                                rs1_use = 0;
                                rs2_use = 0;
                                vj[i] <= from_decoder_pc;
                                vk[i] <= from_decoder_imm;
                            end
                            
                            if (rs1_use == 1) begin
                                vj_ready[i] <= 0;
                                if (reorder_busy[from_decoder_rs1]) begin
                                    qj[i] <= reorder[from_decoder_rs1];
                                    end else if (from_rob_update && rd[from_rob_update_order] == from_decoder_rs1) begin
                                    qj[i] <= from_rob_update_wdata;
                                    end else begin
                                    reg_file_index  <= i;
                                    to_reg_file     <= 1;
                                    to_reg_file_rs1 <= from_decoder_rs1;
                                end
                                end else begin
                                vj_ready[i]     <= 1;
                                to_reg_file_rs1 <= 0;
                            end
                            
                            if (rs2_use == 1) begin
                                vk_ready[i] <= 0;
                                if (reorder_busy[from_decoder_rs2]) begin
                                    qk[i] <= reorder[from_decoder_rs2];
                                    end else if (from_rob_update && rd[from_rob_update_order] == from_decoder_rs2) begin
                                    qk[i] <= from_rob_update_wdata;
                                    end else begin
                                    reg_file_index  <= i;
                                    to_reg_file     <= 1;
                                    to_reg_file_rs2 <= from_decoder_rs2;
                                end
                                end else begin
                                vj_ready[i]     <= 1;
                                to_reg_file_rs2 <= 0;
                            end
                            
                            if (rd_use == 1) begin
                                reorder_busy[from_decoder_rd] <= 1;
                                reorder[from_decoder_rd]      <= i;
                            end
                        end
                    end
                end
            end
            
            
            
            if (to_alu && ! from_rob) begin
                if (alu_double[alu_index] == 0)begin
                    commited[alu_index] <= 1;
                    to_rob              <= 1;
                    to_rob_index        <= alu_index;
                    to_rob_tag          <= rob_tag[alu_index];
                    to_rob_op           <= op_rob[alu_index];
                    to_rob_rd           <= rd[alu_index];
                    if (op_rob[alu_index] == `WRITE_rob) begin
                        to_rob_wdata <= from_alu_result;
                        end else if (op_rob[alu_index] == `JUMP_rob) begin
                        to_rob_jump <= from_alu_result;
                        end else if (op_rob[alu_index] == `BOTH_rob) begin
                        to_rob_wdata <= pc[alu_index];
                        to_rob_jump  <= from_alu_result;
                        end else if (op_rob[alu_index] == `LS_rob) begin
                        to_lsb         <= 1;
                        to_lsb_op      <= op_lsb[alu_index];
                        to_lsb_address <= from_alu_result;
                        to_lsb_wdata   <= vk[alu_index];
                        to_lsb_rd      <= rd[alu_index];
                    end
                    end else begin
                    if (from_alu_result == 32'b1) begin
                        to_alu                <= 1;
                        alu_double[alu_index] <= 0;
                        to_alu_op             <= `ADD_alu_pc;
                        to_alu_a              <= imm[alu_index];
                        to_alu_b              <= pc[alu_index];
                        end else begin
                        commited[alu_index] <= 1;
                        to_rob              <= 1;
                        to_rob_index        <= alu_index;
                        to_rob_tag          <= rob_tag[alu_index];
                        to_rob_op           <= `NOTHING_rob;
                    end
                end
            end
            
            if (from_reg_file)begin
                vj_ready[reg_file_index] <= 1;
                vj[reg_file_index]       <= from_reg_file_rs1;
                vk_ready[reg_file_index] <= 1;
                vk[reg_file_index]       <= from_reg_file_rs2;
            end
            
            for(i = 0; i < RS_SIZE; i++) begin
                if (busy[i] && !cal[i] && vj_ready[i] && vk_ready[i]) begin
                    to_alu    <= 1;
                    alu_index <= i;
                    to_alu_a  <= vj[i];
                    if (op_lsb[i] == `SB_lsb || op_lsb[i] == `SH_lsb || op_lsb[i] == `SW_lsb)begin
                        to_alu_b <= imm[i];
                        end else begin
                        to_alu_b <= vk[i];
                    end
                    to_alu_b  <= vk[i];
                    to_alu_op <= op[i];
                    cal[i]    <= 1; // 用作alu
                end
            end
        end
    end
endmodule //rs
