`define WRITE 3'b000
`define JUMP 3'b001
`define BOTH 3'b010
`define LS 3'b011
`define NOTHING 3'b100

module rob#(parameter ROB_WIDTH = 4,
            parameter ROB_SIZE = 16,
            parameter RS_WIDTH = 2)
           (input rst_in,
            input clk_in,
            input rdy_in,
            input from_decoder,
            input from_rs,
            input [ROB_WIDTH-1:0] from_rs_tag,
            input [2:0] from_rs_op,
            input [4:0] from_rs_rd,
            input [31:0] from_rs_wdata,
            input [31:0] from_rs_jump,
            output reg clear,
            output reg to_decoder,
            output reg to_reg_file,
            output reg [4:0] to_reg_file_rd,
            output reg [31:0] to_reg_file_wdata,
            output reg to_lsb,
            output reg [ROB_WIDTH-1:0] to_lsb_tag,
            output reg to_rs,
            output reg to_rs_update,
            output reg [RS_WIDTH-1:0] to_rs_update_order,
            output reg [31:0] to_rs_update_wdata,
            output reg [31:0] to_if_pc);
    reg [ROB_WIDTH-1:0] head;
    reg [ROB_WIDTH-1:0] tail;
    reg ready[ROB_SIZE-1:0];
    reg [2:0] op[ROB_SIZE-1:0];
    reg [4:0] rd[ROB_SIZE-1:0];
    reg [31:0] wdata[ROB_SIZE-1:0];
    reg [31:0] jump[ROB_SIZE-1:0];
    reg [ROB_WIDTH-1:0] tail_tmp;
    always @(posedge clk_in or posedge rst_in)begin
        if (rdy_in) begin
            if (rst_in || clear) begin
                head           <= 0;
                tail           <= 0;
                to_decoder     <= 1;
                to_lsb         <= 0;
                to_rs          <= 0;
                to_rs_update   <= 0;
                clear          <= 0;
                end else begin
                if (head != tail)begin
                    if (ready[head]) begin
                        clear              <= 0;
                        to_rs_update       <= 1;
                        to_rs_update_order <= head;
                        to_rs_update_wdata <= wdata[head];
                        head               <= head + 1;
                        if (op[head] == `WRITE) begin
                            to_reg_file       <= 1;
                            to_reg_file_rd    <= rd[head];
                            to_reg_file_wdata <= wdata[head];
                            end else if (op[head] == `JUMP) begin
                            clear    <= 1;
                            to_if_pc <= jump[head];
                            end else if (op[head] == `BOTH) begin
                            to_reg_file       <= 1;
                            to_reg_file_rd    <= rd[head];
                            to_reg_file_wdata <= wdata[head];
                            clear             <= 1;
                            to_if_pc          <= jump[head];
                            end else if (op[head] == `LS) begin
                            to_lsb     <= 1;
                            to_lsb_tag <= head;
                        end
                    end
                end

                tail_tmp = tail + 2;
                if (tail_tmp == head) begin
                    to_decoder <= 0;
                    to_rs      <= 0;
                end else begin
                        to_rs          <= 1;
                        if (from_decoder) begin
                        to_decoder     <= 1;
                        ready[tail]    <= 0;
                        tail           <= tail +1;
                    end
                end
                
                if (from_rs) begin
                    ready[from_rs_tag]    <= 1;
                    op[from_rs_tag]       <= from_rs_op;
                    rd[from_rs_tag]       <= from_rs_rd;
                    wdata[from_rs_tag]    <= from_rs_wdata;
                    jump[from_rs_tag]     <= from_rs_jump;
                end
            end
        end
    end
endmodule //rob
