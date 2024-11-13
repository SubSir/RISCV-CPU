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
            output reg to_decoder,
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
    reg [LSB_WIDTH-1:0] head_tmp;
    reg [LSB_WIDTH-1:0] tail_tmp;
    always @(posedge clk_in or posedge rst_in)begin
        if (rdy_in) begin
            if (rst_in || clear) begin
                head       <= 0;
                tail       <= 0;
                to_decoder <= 1;
                to_rob     <= 0;
                to_if      <= 0;
                remain     <= 3'b00;
                end else begin

                to_decoder <= 1;
                if (from_decoder) begin
                    tag[tail]     <= from_decoder_tag;
                    tail          <= tail +1;
                    ready[tail]   <= 0;
                    execute[tail] <= 0;
                    tail_tmp = tail + 2;
                    if (tail_tmp == head)begin
                        to_decoder <= 0;
                    end
                end
                
                if (from_rs) begin
                    for(i = head;i != tail;i = i + 1)begin
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
                
                next = 0;
                to_rob <= 0;
                if (to_if) begin
                    mem_dout          <= store_data[remain];
                    if (!bubble)begin
                        load_data[remain] <= mem_din;
                    end else begin
                        bubble <= 0;
                    end
                    if (remain != 3'b00) begin
                        mem_a  <= mem_a + 32'd1;
                        remain <= remain - 3'b1;
                        end else begin
                        next     = 1;
                        to_rob_tag <= tag[head];
                        if (op[head] == `lsb_LB) begin
                            $display("0 TERM L3 LB tag: %d, data: %d", tag[head], {{24{mem_din[7]}}, mem_din});
                            to_rob <= 1;
                            to_rob_data <= {{24{mem_din[7]}}, mem_din};
                            end else if (op[head] == `lsb_LBU) begin
                            $display("0 TERM L3 LBU tag: %d, data: %d", tag[head], {24'h000000, mem_din});
                            to_rob <= 1;
                            to_rob_data <= {24'h000000, mem_din};
                            end else if (op[head] == `lsb_LH) begin
                            $display("0 TERM L3 LH tag: %d, data: %d", tag[head], {{16{mem_din[7]}}, mem_din, load_data[1]});
                            to_rob <= 1;
                            to_rob_data <= {{16{mem_din[7]}}, mem_din, load_data[1]};
                            end else if (op[head] == `lsb_LHU) begin
                            $display("0 TERM L3 LHU tag: %d, data: %d", tag[head], {16'h0000, mem_din, load_data[1]});
                            to_rob <= 1;
                            to_rob_data <= {16'h0000, mem_din, load_data[1]};
                            end else if (op[head] == `lsb_LW) begin
                            $display("0 TERM L3 LW tag: %d, data: %d", tag[head], {mem_din, load_data[1], load_data[2], load_data[3]});
                            to_rob <= 1;
                            to_rob_data <= {mem_din, load_data[1], load_data[2], load_data[3]};
                        end
                    end
                end
                
                head_tmp = head + next;
                if (!to_if || remain == 3'b0) begin
                    head <= head_tmp;
                    if (head_tmp == tail || !ready[head_tmp]) begin
                        to_if <= 0;
                        end else begin
                        to_if <= 1;
                        bubble <= 1;
                        mem_a <= address[head_tmp];
                        if (op[head_tmp] == `lsb_LB || op[head_tmp] == `lsb_LBU) begin
                            $display("0 TERM L3 tag: %d, begin lb, address: %h", tag[head_tmp], address[head_tmp]);
                            remain <= 3'd1;
                            mem_wr <= 0;
                            end else if (op[head_tmp] == `lsb_LH | op[head_tmp] == `lsb_LHU) begin
                            $display("0 TERM L3 tag: %d, begin lh, address: %h", tag[head_tmp], address[head_tmp]);
                            remain <= 3'd2;
                            mem_wr <= 0;
                            end else if (op[head_tmp] == `lsb_LW) begin
                            $display("0 TERM L3 tag: %d, begin lw, address: %h", tag[head_tmp], address[head_tmp]);
                            remain <= 3'd4;
                            mem_wr <= 0;
                            end else if (execute[head_tmp] && op[head_tmp] == `lsb_SB) begin
                            $display("0 TERM L3 tag: %d, begin sb, address: %h, wdata: %d", tag[head_tmp], address[head_tmp], wdata[head_tmp][7:0]);
                            remain        <= 3'd0;
                            mem_dout <= wdata[head_tmp][7:0];
                            mem_wr <= 1;
                            end else if (execute[head_tmp] && op[head_tmp] == `lsb_SH) begin
                            $display("0 TERM L3 tag: %d, begin sh, address: %h, wdata: %d", tag[head_tmp], address[head_tmp], wdata[head_tmp][15:8]);
                            remain        <= 3'd1;
                            store_data[1] <= wdata[head_tmp][15:8];
                            mem_wr <= 1;
                            mem_dout <= wdata[head_tmp][7:0];
                            end else if (execute[head_tmp] && op[head_tmp] == `lsb_SW) begin
                            $display("0 TERM L3 tag: %d, begin sw, address: %h, wdata: %d", tag[head_tmp], address[head_tmp], wdata[head_tmp]);
                            remain        <= 3'd3;
                            store_data[1] <= wdata[head_tmp][31:24];
                            store_data[2] <= wdata[head_tmp][23:16];
                            store_data[3] <= wdata[head_tmp][15:8];
                            mem_dout <= wdata[head_tmp][7:0];
                            mem_wr <= 1;
                            end else begin
                            to_if <= 0;
                            bubble <= 0;
                        end
                    end
                end
            end
        end
    end
    
endmodule //Lsb
