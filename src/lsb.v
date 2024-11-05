`define LB 3'b000
`define LBU 3'b001
`define LH 3'b010
`define LHU 3'b011
`define LW 3'b100
`define SB 3'b101
`define SH 3'b110
`define SW 3'b111

module lsb#(parameter LSB_SIZE = 4,
            parameter LSB_WIDTH = 2,
            parameter ROB_WIDTH = 4)
           (input rst_in,
            input clk_in,
            input rdy_in,
            input clear,
            input from_decoder,
            input [31:0] from_decoder_tag,
            input from_rs,
            input [3:0]from_rs_op,
            input [4:0] from_rs_rd,
            input [31:0]from_rs_wdata,
            input [31:0]from_rs_address,
            input from_rob,
            input [ROB_WIDTH-1:0]from_rob_tag,
            input [7:0] mem_din,
            output [7:0] mem_dout,
            output [31:0] mem_a,
            output mem_wr,
            output reg to_if,
            output reg to_decoder,
            output reg to_rob,
            output reg [31:0]to_rob_data,
            output reg [4:0] to_rob_rd,
            );
    reg ready[0:ROB_DEPTH-1];
    reg execute[0:ROB_DEPTH-1];
    reg [LSB_WIDTH-1:0] head;
    reg [LSB_WIDTH-1:0] tail;
    reg [ROB_WIDTH-1:0] tag[0:LSB_SIZE-1];
    reg [4:0] rd[0:LSB_SIZE-1];
    reg [3:0] op[0:LSB_SIZE-1];
    reg [31:0] wdata[0:LSB_SIZE-1];
    reg [31:0] address[0:LSB_SIZE-1];
    reg [1:0] remain;
    reg [7:0] load_data[0:3];
    reg [7:0] store_data[0:3];
    always @(posedge clk_in or posedge rst_in)begin
        if (rdy_in) begin
            if (rst_in || clear) begin
                head       <= 0;
                tail       <= 0;
                to_decoder <= 1;
                to_rob     <= 0;
                to_if      <= 0;
                remain     <= 2'b00;
                end else begin
                if (from_decoder) begin
                    tag[tail]     <= from_decoder_tag;
                    tail          <= tail +1;
                    ready[tail]   <= 0;
                    execute[tail] <= 0;
                    if (tail + 2 == head)begin
                        to_decoder <= 0;
                        end else begin
                        to_decoder <= 1;
                    end
                end
                
                if (from_rs)begin
                    logic found = 0;
                    for(int i = head;i! = tail;i++)begin
                        if (!found && tag[i] == from_rs_tag)begin
                            rd[i]      <= from_rs_rd;
                            wdata[i]   <= from_rs_wdata;
                            address[i] <= from_rs_address;
                            found = 1;
                            ready[i] <= 1;
                        end
                    end
                end
                
                if (from_rob) begin
                    logic found = 0;
                    for(int i = head; i! = tail; i++)begin
                        if (tag[i] == from_rob_tag)begin
                            found = 1;
                            execute[i] <= 1;
                        end
                    end
                end
                
                logic next = 0;
                
                to_rob <= 0;
                if (to_if) begin
                    load_data[remain] <= mem_din;
                    mem_dout          <= store_data[remain];
                    if (remain ! = 2'b00) begin
                        mem_a  <= mem_a + 32'd4;
                        remain <= remain - 2'b01;
                        end else begin
                        next     = 1;
                        to_rob < = 1;
                        to_rob_rd <= rd[head];
                        if (op[head] == `LB) begin
                            to_rob_data <= {{24{load_data[0][7]}}, load_data[0]};
                            end else if (op[head] == `LBU) begin
                            to_rob_data <= {24'h000000, load_data[0]};
                            end else if (op[head] == `LH) begin
                            to_rob_data <= {{16{load_data[0][15]}}, load_data[1], load_data[0]};
                            end else if (op[head] == `LHU) begin
                            to_rob_data <= {16'h0000, load_data[1], load_data[0]};
                            end else if (op[head] == `LW) begin
                            to_rob_data <= {load_data[3], load_data[2], load_data[1], load_data[0]};
                        end
                    end
                end
                
                logic head_tmp = head + next;
                if (!to_if or remain == 2'b00) begin
                    head <= head_tmp;
                    if (head_tmp == tail) begin
                        to_if <= 0;
                        end else begin
                        to_if <= 1;
                        mem_a <= address[head_tmp];
                        if (op[head_tmp] == `LB || op[head_tmp] == `LBU) begin
                            remain <= 2'b00;
                            mem_wr <= 0;
                            end else if (op[head_tmp] == `LH | op[head_tmp] == `LHU) begin
                            remain <= 2'b01;
                            mem_wr <= 0;
                            end else if (op[head_tmp] == `LW) begin
                            remain <= 2'b11;
                            mem_wr <= 0;
                            end else if (execute[head_tmp] && op[head_tmp] == `SB) begin
                            remain        <= 2'b00;
                            store_data[0] <= wdata[head_tmp][7:0];
                            end else if (execute[head_tmp] && op[head_tmp] == `SH) begin
                            remain        <= 2'b01;
                            store_data[0] <= wdata[head_tmp][15:8];
                            store_data[1] <= wdata[head_tmp][7:0];
                            end else if (execute[head_tmp] && op[head_tmp] == `SW) begin
                            remain        <= 2'b11;
                            store_data[0] <= wdata[head_tmp][31:24];
                            store_data[1] <= wdata[head_tmp][23:16];
                            store_data[2] <= wdata[head_tmp][15:8];
                            store_data[3] <= wdata[head_tmp][7:0];
                            end else begin
                            to_if <= 0;
                        end
                    end
                end
            end
        end
    end
    
endmodule //lsb
