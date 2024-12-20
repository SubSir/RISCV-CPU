`define WRITE 3'b000
`define JUMP 3'b001
`define BOTH 3'b010
`define LOAD 3'b011
`define STORE 3'b100
`define NOTHING 3'b101

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
            input from_lsb,
            input [ROB_WIDTH-1:0] from_lsb_tag,
            input [31:0] from_lsb_wdata,
            output reg clear,
            output reg to_if_bsy,
            output reg to_reg_file,
            output reg [4:0] to_reg_file_rd,
            output reg [31:0] to_reg_file_wdata,
            output reg to_lsb,
            output reg [ROB_WIDTH-1:0] to_lsb_tag,
            output reg to_rs,
            output reg to_rs_update,
            output reg [ROB_WIDTH-1:0] to_rs_update_order,
            output reg [31:0] to_rs_update_wdata,
            output reg [31:0] to_if_pc);
    reg [ROB_WIDTH-1:0] head;
    reg [ROB_WIDTH-1:0] tail;
    reg ready[ROB_SIZE-1:0];
    reg execute[ROB_SIZE-1:0];
    reg [2:0] op[ROB_SIZE-1:0];
    reg [4:0] rd[ROB_SIZE-1:0];
    reg [31:0] wdata[ROB_SIZE-1:0];
    reg [31:0] jump[ROB_SIZE-1:0];
    reg [ROB_WIDTH:0] busy_cnt;
    reg [ROB_WIDTH:0] busy_cnt_tmp;

    always @(posedge clk_in)begin
        if (rst_in) begin
            head           <= 0;
            tail           <= 0;
            to_if_bsy     <= 1;
            to_lsb         <= 0;
            to_rs          <= 0;
            to_rs_update   <= 0;
            clear          <= 0;
            busy_cnt       <= 0;
        end else begin
            if (rdy_in) begin
                if (clear) begin
                    head           <= 0;
                    tail           <= 0;
                    to_if_bsy     <= 1;
                    to_lsb         <= 0;
                    to_rs          <= 0;
                    to_rs_update   <= 0;
                    clear          <= 0;
                    busy_cnt       <= 0;
                    end else begin
                    busy_cnt_tmp = busy_cnt;
                    to_lsb  <= 0;
                    to_reg_file       <= 0;
                    to_rs_update   <= 0;
                    if (head != tail) begin
                        if (ready[head] && execute[head]) begin
                            clear              <= 0;
                            to_rs_update_order <= head;
                            to_rs_update_wdata <= wdata[head];
                            head               <= head + 1;
                            busy_cnt_tmp = busy_cnt_tmp - 1;
                            if (op[head] == `WRITE) begin
                                    // $display("0 CMIT R2 WRITE tag: %d, rd: %d, wdata: %d", head, rd[head], wdata[head]);
                                    to_rs_update       <= 1;
                                    to_reg_file       <= 1;
                                    to_reg_file_rd    <= rd[head];
                                    to_reg_file_wdata <= wdata[head];
                                end else if (op[head] == `JUMP) begin
                                    // $display("0 CMIT R2 JUMP tag: %d, jump: %h", head, jump[head]);
                                    clear    <= 1;
                                    to_if_pc <= jump[head];
                                end else if (op[head] == `BOTH) begin
                                    // $display("0 CMIT R2 BOTH tag: %d, rd: %d, wdata: %h, jump: %h", head, rd[head], wdata[head], jump[head]);
                                    to_rs_update       <= 1;
                                    to_reg_file       <= 1;
                                    to_reg_file_rd    <= rd[head];
                                    to_reg_file_wdata <= wdata[head];
                                    clear             <= 1;
                                    to_if_pc          <= jump[head];
                                end else if (op[head] == `LOAD) begin
                                    // $display("0 CMIT R2 LOAD tag: %d, rd: %d, data: %d", head, rd[head], wdata[head]);
                                    to_rs_update       <= 1;
                                    to_reg_file       <= 1;
                                    to_reg_file_rd    <= rd[head];
                                    to_reg_file_wdata <= wdata[head];
                                end else if (op[head] == `STORE) begin
                                    // $display("0 CMIT R2 STORE tag: %d", head);
                                    to_lsb     <= 1;
                                    to_lsb_tag <= head;
                                end else begin
                                    // $display("0 CMIT R2 NOTHING tag: %d", head);
                            end
                        end else if (ready[head] && op[head] == `LOAD) begin
                            to_lsb     <= 1;
                            to_lsb_tag <= head;
                        end
                    end

                    if (from_decoder) begin
                        ready[tail]    <= 0;
                        execute[tail]    <= 0;
                        tail           <= tail +1;
                        busy_cnt_tmp = busy_cnt_tmp + 1;
                    end

                    if (busy_cnt_tmp + 4 >= ROB_SIZE) begin
                        to_if_bsy <= 0;
                        to_rs      <= 0;
                    end else begin
                        to_rs          <= 1;
                        to_if_bsy     <= 1;
                    end
                    
                    if (from_rs) begin
                        ready[from_rs_tag] <= 1;
                        if (from_rs_op == `LOAD) begin
                            execute[from_rs_tag]    <= 0;
                        end else begin
                            execute[from_rs_tag]    <= 1;
                        end
                        op[from_rs_tag]       <= from_rs_op;
                        rd[from_rs_tag]       <= from_rs_rd;
                        wdata[from_rs_tag]    <= from_rs_wdata;
                        jump[from_rs_tag]     <= from_rs_jump;
                    end

                    if (from_lsb) begin
                        execute[from_lsb_tag] <= 1;
                        wdata[from_lsb_tag] <= from_lsb_wdata;
                    end

                    busy_cnt <= busy_cnt_tmp;
                end
            end
        end
    end
endmodule //rob
