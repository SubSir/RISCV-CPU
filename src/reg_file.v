module RegisterFile (input rst_in,
                     input clk_in,
                     input rdy_in,
                     input from_rs,
                     input [4:0] from_rs_rs1,
                     input [4:0] from_rs_rs2,
                     input from_rob,
                     input [4:0] from_rob_rd,
                     input [31:0] from_rob_wdata,
                     output reg [31:0] to_rs_rs1,
                     output reg [31:0] to_rs_rs2,
                     );
    reg [31:0] reg_file [0:31];
    
    always_ff @(posedge clk_in or posedge rst_in) begin
        if (rdy_in)begin
            if (rst_in) begin
                for (int i = 0; i < 32; i++) begin
                    reg_file[i] <= 32'b0;
                end
                end else begin
                if (from_rs) begin
                    to_rs_rs1 <= reg_file[from_rs_rs1];
                    to_rs_rs2 <= reg_file[from_rs_rs2];
                end
                
                if (from_rob) begin
                    reg_file[from_rob_rd] <= from_rob_wdata;
                end
            end
        end
    end
    
    
endmodule // RegisterFile
