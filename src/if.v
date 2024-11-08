module IF #(parameter IF_WIDTH = 2,
            parameter IF_SIZE = 4)
           (input rst_in,
            input clk_in,
            input rdy_in,
            input clear,
            input [7:0] mem_din,
            input from_lsb,
            input [31:0]from_rob_jump,
            output reg mem_wr,
            output reg [31:0] mem_a,
            output reg to_decoder,
            output reg [31:0]to_decoder_ins,
            output reg [31:0]to_decoder_pc);
    reg [31:0] pc;
    reg [IF_WIDTH-1:0] head;
    reg [IF_WIDTH-1:0] tail;
    reg [31:0] ins[0:IF_SIZE-1];
    reg [31:0] ins_pc[0:IF_SIZE-1];
    reg loading;
    reg [1:0] remain;
    reg [7:0] load_data[0:3];
    reg next;
    reg [31:0] pc_tmp;
    reg [IF_WIDTH-1:0] tail_tmp;
    always @(posedge clk_in or posedge rst_in)begin
        if (rdy_in) begin
            if (rst_in || clear) begin
                head       <= 0;
                tail       <= 0;
                remain     <= 2'b00;
                loading    <= 0;
                to_decoder <= 0;
                if (rst_in) begin
                    pc <= 32'b0;
                    end else begin
                    loading <= 0;
                    pc      <= from_rob_jump;
                end
                end else begin
                if (!from_lsb) begin
                    next   = 0;
                    pc_tmp = pc;
                    if (loading) begin
                        load_data[remain] <= mem_din;
                        if (remain != 2'b00) begin
                            mem_a  <= mem_a + 32'd1;
                            remain <= remain -2'b01;
                            end else begin
                            next = 1;
                            ins[tail]    <= {load_data[3], load_data[2], load_data[1], load_data[0]};
                            ins_pc[tail] <= pc;
                            pc           <= pc + 32'd4;
                            pc_tmp = pc+32'd4;
                        end
                    end
                    
                    tail_tmp = tail + next;
                    if (!loading || remain == 2'b00) begin
                        loading <= 1;
                        tail    <= tail_tmp;
                        if (tail_tmp + 1 != head) begin
                            remain <= 2'b11;
                            mem_wr <= 0;
                            mem_a  <= pc_tmp;
                            end else begin
                            loading <= 0;
                        end
                    end
                end
                
                if (head == tail) begin
                    to_decoder <= 0;
                    end else begin
                    to_decoder     <= 1;
                    to_decoder_pc  <= ins_pc[head];
                    to_decoder_ins <= ins[head];
                    head           <= head + 1;
                end
            end
        end
    end
endmodule //IF
