`define lsb_LB 3'b000
`define lsb_LBU 3'b001
`define lsb_LH 3'b010
`define lsb_LHU 3'b011
`define lsb_LW 3'b100
`define lsb_SB 3'b101
`define lsb_SH 3'b110
`define lsb_SW 3'b111

module Lsb#(parameter LSB_SIZE = 4,
            parameter LSB_WIDTH = 2,
            parameter ROB_WIDTH = 4)
           (input rst_in,
            input clk_in,
            input rdy_in,
            input clear,
            input from_decoder,
            input [ROB_WIDTH-1:0] from_decoder_tag,
            input from_rs,
            input [3:0]from_rs_op,
            input [ROB_WIDTH-1:0] from_rs_tag,
            input [31:0]from_rs_wdata,
            input [31:0]from_rs_address,
            input from_rob,
            input [ROB_WIDTH-1:0]from_rob_tag,
            input [7:0] mem_din,
            output reg [7:0] mem_dout,
            output reg [31:0] mem_a,
            output reg mem_wr,
            output reg to_if,
            output reg to_if_bsy,
            output reg to_rob,
            output reg [31:0]to_rob_data,
            output reg [ROB_WIDTH-1:0] to_rob_tag
            );
    reg ready[0:LSB_SIZE-1];
    reg execute[0:LSB_SIZE-1];
    reg [LSB_WIDTH-1:0] head;
    reg [LSB_WIDTH-1:0] tail;
    reg [ROB_WIDTH-1:0] tag[0:LSB_SIZE-1];
    reg [3:0] op[0:LSB_SIZE-1];
    reg [31:0] wdata[0:LSB_SIZE-1];
    reg [31:0] address[0:LSB_SIZE-1];
    reg [2:0] remain;
    reg [7:0] load_data[0:3];
    reg [7:0] store_data[0:3];
    reg [LSB_WIDTH-1:0]i;
    reg next;
    reg bubble;
    reg break;
    reg [LSB_WIDTH:0] busy_cnt;
    reg [LSB_WIDTH:0] busy_cnt_tmp;
    always @(posedge clk_in or posedge rst_in) begin
        if (rdy_in) begin
            if (rst_in || clear) begin
                to_if_bsy <= 1;
                to_rob     <= 0;
                if (rst_in) begin
                    to_if <= 0;
                    head <= 0;
                    tail <= 0;
                    busy_cnt <= 0;
                end else begin
                    next = 1;
                    busy_cnt_tmp = 0;
                    if (head != tail) begin
                        break = 0;
                        for (i = head; i != tail; i = i + 1) begin
                            if (!break && !execute[i]) begin
                                tail <= i;
                                break = 1;
                            end else if (!break) begin
                                busy_cnt_tmp = busy_cnt_tmp + 1;
                            end

                            if (execute[i]) begin
                                next = 0;
                            end
                        end

                        if (next) begin
                            to_if <= 0;
                            remain <= 0;
                        end
                    end
                    busy_cnt <= busy_cnt_tmp;
                end
                end else begin
                busy_cnt_tmp = busy_cnt;
                to_if_bsy <= 1;
                if (from_decoder) begin
                    tag[tail]     <= from_decoder_tag;
                    tail          <= tail +1;
                    ready[tail]   <= 0;
                    execute[tail] <= 0;
                    busy_cnt_tmp = busy_cnt_tmp + 1;
                end
                
                if (from_rs) begin
                    for(i = head; i != tail; i = i + 1)begin
                        if (tag[i] == from_rs_tag) begin 
                            op[i]       <= from_rs_op;
                            wdata[i]   <= from_rs_wdata;
                            address[i] <= from_rs_address;
                            ready[i] <= 1;
                        end
                    end
                end
                
                if (from_rob) begin
                    for(i = head; i != tail; i = i + 1)begin
                        if (tag[i] == from_rob_tag)begin
                            execute[i] <= 1;
                        end
                    end
                end
                
                to_rob <= 0;
                if (to_if) begin
                    mem_dout          <= store_data[remain];
                    if (!bubble) begin
                        load_data[remain] <= mem_din;
                    end else begin
                        bubble <= 0;
                    end
                    if (remain != 3'b00) begin
                        mem_a  <= mem_a + 32'd1;
                        remain <= remain - 3'b1;
                        end else begin
                        to_if <= 0;
                        head <= head + 1;
                        busy_cnt_tmp = busy_cnt_tmp - 1;
                        to_rob_tag <= tag[head];
                        if (op[head] == `lsb_LB) begin
                            // $display("0 TERM L3 LB tag: %d, data: %d", tag[head], {{24{mem_din[7]}}, mem_din});
                            to_rob <= 1;
                            to_rob_data <= {{24{mem_din[7]}}, mem_din};
                            end else if (op[head] == `lsb_LBU) begin
                            // $display("0 TERM L3 LBU tag: %d, data: %d", tag[head], {24'h000000, mem_din});
                            to_rob <= 1;
                            to_rob_data <= {24'h000000, mem_din};
                            end else if (op[head] == `lsb_LH) begin
                            // $display("0 TERM L3 LH tag: %d, data: %d", tag[head], {{16{mem_din[7]}}, mem_din, load_data[1]});
                            to_rob <= 1;
                            to_rob_data <= {{16{mem_din[7]}}, mem_din, load_data[1]};
                            end else if (op[head] == `lsb_LHU) begin
                            // $display("0 TERM L3 LHU tag: %d, data: %d", tag[head], {16'h0000, mem_din, load_data[1]});
                            to_rob <= 1;
                            to_rob_data <= {16'h0000, mem_din, load_data[1]};
                            end else if (op[head] == `lsb_LW) begin
                            // $display("0 TERM L3 LW tag: %d, data: %d", tag[head], {mem_din, load_data[1], load_data[2], load_data[3]});
                            to_rob <= 1;
                            to_rob_data <= {mem_din, load_data[1], load_data[2], load_data[3]};
                            end else begin
                            // $display("0 ERRO L3 tag: %d finish", tag[head]);
                            end
                    end
                end
                
                if (!to_if) begin
                    if (head == tail || !ready[head]) begin
                        to_if <= 0;
                        end else begin
                        to_if <= 1;
                        bubble <= 1;
                        mem_a <= address[head];
                        if (op[head] == `lsb_LB || op[head] == `lsb_LBU) begin
                            // $display("0 TERM L3 tag: %d, begin lb, address: %h", tag[head], address[head]);
                            remain <= 3'd1;
                            mem_wr <= 0;
                            end else if (op[head] == `lsb_LH | op[head] == `lsb_LHU) begin
                            // $display("0 TERM L3 tag: %d, begin lh, address: %h", tag[head], address[head]);
                            remain <= 3'd2;
                            mem_wr <= 0;
                            end else if (op[head] == `lsb_LW) begin
                            // $display("0 TERM L3 tag: %d, begin lw, address: %h", tag[head], address[head]);
                            remain <= 3'd4;
                            mem_wr <= 0;
                            end else if (execute[head] && op[head] == `lsb_SB) begin
                            // $display("0 TERM L3 tag: %d, begin sb, address: %h, wdata: %d", tag[head], address[head], wdata[head][7:0]);
                            remain        <= 3'd0;
                            mem_dout <= wdata[head][7:0];
                            mem_wr <= 1;
                            end else if (execute[head] && op[head] == `lsb_SH) begin
                            // $display("0 TERM L3 tag: %d, begin sh, address: %h, wdata: %d", tag[head], address[head], wdata[head][15:8]);
                            remain        <= 3'd1;
                            store_data[1] <= wdata[head][15:8];
                            mem_wr <= 1;
                            mem_dout <= wdata[head][7:0];
                            end else if (execute[head] && op[head] == `lsb_SW) begin
                            // $display("0 TERM L3 tag: %d, begin sw, address: %h, wdata: %d", tag[head], address[head], wdata[head]);
                            remain        <= 3'd3;
                            store_data[1] <= wdata[head][31:24];
                            store_data[2] <= wdata[head][23:16];
                            store_data[3] <= wdata[head][15:8];
                            mem_dout <= wdata[head][7:0];
                            mem_wr <= 1;
                            end else begin
                            to_if <= 0;
                            bubble <= 0;
                        end
                    end
                end

                to_if_bsy <= (busy_cnt_tmp + 3 < LSB_SIZE);
                busy_cnt <= busy_cnt_tmp;
            end
        end
    end
    
endmodule //Lsb
