module decoder #(parameter ROB_WIDTH = 4)
                (input rst_in,
                 input clk_in,
                 input rdy_in,
                 input clear,
                 input [31:0] instruction,
                 input from_rob,
                 input [ROB_WIDTH-1:0]from_rob_tag,
                 output reg to_rs,
                 output reg to_lsb,
                 output reg to_rob,
                 );
    always @(posedge clk_in) begin
        
    end
    
    
endmodule //decoder
