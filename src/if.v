module IF #(parameter IF_WIDTH = 2,
            parameter IF_SIZE = 4,
            parameter CACHE_WIDTH = 4,
            parameter CACHE_SIZE = 16,
            parameter TAG_WIDTH = 16-CACHE_WIDTH)
           (input rst_in,
            input clk_in,
            input rdy_in,
            input clear,
            input [7:0] mem_din,
            input from_lsb,
            input [31:0]from_rob_jump,
            input from_rs_bsy,
            input from_lsb_bsy,
            input from_rob_bsy,
            output reg mem_wr,
            output reg [31:0] mem_a,
            output reg to_decoder,
            output reg [31:0]to_decoder_ins,
            output reg [31:0]to_decoder_pc,
            output reg [31:0]to_decoder_pc_next);
    reg [31:0] pc;
    reg [IF_WIDTH-1:0] head;
    reg [IF_WIDTH-1:0] tail;
    reg [31:0] ins[0:IF_SIZE-1];
    reg [31:0] ins_pc[0:IF_SIZE-1];
    reg [31:0] ins_pc_next[0:IF_SIZE-1];
    reg loading;
    reg [2:0] remain;
    reg [7:0] load_data[0:3];
    reg [IF_WIDTH-1:0] tail_tmp;
    reg bubble;
    reg [31:0] tmp_mem_a;
    reg cache_busy[0:CACHE_SIZE-1];
    reg [TAG_WIDTH-1:0] cache_tag[0:CACHE_SIZE-1];
    reg [31:0] cache_data[0:CACHE_SIZE-1];
    reg [31:0] cache_pc_next[0:CACHE_SIZE-1];

    integer i;

    wire [TAG_WIDTH-1:0] tag = pc[16:17-TAG_WIDTH];
    wire [CACHE_WIDTH-1:0] cache_index = pc[16-TAG_WIDTH:1];

    always @(posedge clk_in)begin
        if (rdy_in) begin
            if (rst_in || clear) begin
                head       <= 0;
                tail       <= 0;
                remain     <= 3'b00;
                loading    <= 0;
                to_decoder <= 0;
                if (rst_in) begin
                    pc <= 32'b0;
                    for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                        cache_busy[i] <= 0;
                    end
                    end else begin
                    loading <= 0;
                    pc      <= from_rob_jump;
                end
                end else begin
                bubble <= from_lsb;
                if (!from_lsb && !bubble) begin
                    if (loading) begin
                        if (remain != 3'd4) begin
                            load_data[remain] <= mem_din;
                        end
                        if (remain == 3'd2 && (load_data[3][0] & load_data[3][1]) == 0) begin
                                loading <= 0;
                                tail <= tail + 1;
                                ins[tail]    <= {12'b0, mem_din, load_data[3]};
                                ins_pc[tail] <= pc;
                                ins_pc_next[tail] <= pc + 32'd2;
                                pc           <= pc + 32'd2;
                                remain = 3'b0;
                                // $display("0 LOG2 I3 i-cache, pc: %h, tag: %h, index: %h, data: %h", pc, tag, cache_index, {12'b0, mem_din, load_data[3]});
                                cache_busy[cache_index] <= 1;
                                cache_tag[cache_index] <= tag;
                                cache_data[cache_index] <= {12'b0, mem_din, load_data[3]};
                                cache_pc_next[cache_index] <= pc + 32'd2;
                            end else if (remain != 3'b0) begin
                                mem_a  <= mem_a + 32'd1;
                                remain <= remain - 3'b1;
                            end else begin
                                loading <= 0;
                                tail <= tail + 1;
                                ins[tail]    <= {mem_din, load_data[1], load_data[2], load_data[3]};
                                ins_pc[tail] <= pc;
                                ins_pc_next[tail] <= pc + 32'd4;
                                pc           <= pc + 32'd4;
                                // $display("0 LOG2 I3 i-cache, pc: %h, tag: %h, index: %h, data: %h", pc, tag, cache_index, {mem_din, load_data[1], load_data[2], load_data[3]});
                                cache_busy[cache_index] <= 1;
                                cache_tag[cache_index] <= tag;
                                cache_data[cache_index] <= {mem_din, load_data[1], load_data[2], load_data[3]};
                                cache_pc_next[cache_index] <= pc + 32'd4;
                        end
                    end
                    
                    tail_tmp = tail + 1;
                    if (!loading) begin
                        loading <= 1;
                        if (tail_tmp != head) begin
                            if (cache_busy[cache_index] && cache_tag[cache_index] == tag) begin
                                // $display("0 LOG2 I3 i-cache hit, pc: %h, tag: %h, index: %h, data: %h", pc , tag, cache_index, cache_data[cache_index]);
                                loading <= 0;
                                ins[tail]    <= cache_data[cache_index];
                                ins_pc[tail] <= pc;
                                ins_pc_next[tail] <= cache_pc_next[cache_index];
                                pc <= cache_pc_next[cache_index];
                                tail <= tail + 1;
                            end else begin
                                remain <= 3'b100;
                                mem_wr <= 0;
                                mem_a  <= pc;
                            end
                            end else begin
                            loading <= 0;
                        end
                    end
                end else if (from_lsb && !bubble) begin
                    loading <= 0;
                end
                
                if (head == tail || !from_rs_bsy || !from_rob_bsy || !from_lsb_bsy) begin
                    to_decoder <= 0;
                    end else begin
                    to_decoder     <= 1;
                    to_decoder_pc  <= ins_pc[head];
                    to_decoder_pc_next <= ins_pc_next[head];
                    to_decoder_ins <= ins[head];
                    head           <= head + 1;
                end
            end
        end
    end
endmodule //IF
