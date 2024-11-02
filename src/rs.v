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
           input [31:0] from_alu_result,
           input from_rob_update,
           input from_rob_update_id,
           input [4:0] from_rob_update_order,      // 位数与RS_SIZE 有关
           input [31:0] from_rob_update_wdata,
           output reg to_alu,
           output reg [31:0] to_alu_a,
           output reg [31:0] to_alu_b,
           output reg to_reg_file,
           output reg [4:0] to_reg_file_rs1,
           output reg [4:0] to_reg_file_rs2,
           output reg to_rob,
           output reg [ROB_WIDTH-1:0] to_rob_tag,
           output reg [31:0] to_rob_op,
           output reg [4:0] to_rob_rd,
           output reg [31:0] to_rob_wdata,
           output reg [31:0] to_rob_jump,
           );
    
    reg busy [0:RS_SIZE-1];
    reg commited [0:RS_SIZE-1];
    reg ready [0:RS_SIZE-1];
    reg [5:0] op [0:RS_SIZE-1];
    reg [4:0] rd [0:RS_SIZE-1];
    reg vj_rd [0:RS_SIZE-1];
    reg [31:0] vj [0:RS_SIZE-1];
    reg [4:0] qj [0:RS_SIZE-1];
    reg vk_rd [0:RS_SIZE-1];
    reg [31:0] vk [0:RS_SIZE-1];
    reg [4:0] qk [0:RS_SIZE-1];
    reg [31:0] imm [0:RS_SIZE-1];
    reg [31:0] pc [0:RS_SIZE-1];
    reg [ROB_WIDTH-1:0] rob_tag [0:RS_SIZE-1];
    reg  reorder_busy [0:31];
    reg [4:0] reorder [0:31];
    reg [4:0] alu_rd;
    reg [4:0] reg_file_rs1;
    reg [4:0] reg_file_rs2;
    
    always @(posedge clk_in or posedge rst_in) begin
        if (rst_in || clear) begin
            for (int i = 0; i < RS_SIZE; i++) begin
                busy[i] <= 0;
            end
            to_rob      <= 0;
            to_alu      <= 0;
            to_reg_file <= 0;
            
            end else begin
            if (from_rob_update) begin
                for(int i = 0; i < RS_SIZE; i++)begin
                    if (busy[i] && qj[i] == from_rob_update_order)begin
                        vj[i]    <= from_rob_update_wdata;
                        vj_rd[i] <= 1;
                    end
                    
                    if (busy[i] && qk[i] == from_rob_update_order)begin
                        vk[i]    <= from_rob_update_wdata;
                        vk_rd[i] <= 1;
                    end
                end
            end
            
            
            if (from_decoder) begin
                
            end
            
            if (to_alu) begin
                
            end
            
            if (from_reg_file)begin
            end
            
        end
    end
endmodule //rs
