module RegisterFile #(parameter RS_WIDTH = 2)(input rst_in,
                     input clk_in,
                     input rdy_in,
                     input from_rs_rs1_flag,
                     input from_rs_rs2_flag,
                     input [4:0] from_rs_rs1,
                     input [4:0] from_rs_rs2,
                     input [RS_WIDTH-1:0] from_rs_index,
                     input from_rob,
                     input [4:0] from_rob_rd,
                     input [31:0] from_rob_wdata,
                     output reg to_rs_rs1_flag,
                     output reg to_rs_rs2_flag,
                     output reg [RS_WIDTH-1:0] to_rs_index,
                     output reg [31:0] to_rs_rs1,
                     output reg [31:0] to_rs_rs2);
    reg [31:0] reg_file [0:31];
    integer i;
    
    always @(posedge clk_in or posedge rst_in) begin
        if (rdy_in)begin
            to_rs_rs1_flag <= 0;
            to_rs_rs2_flag <= 0;
            if (rst_in) begin
                for (i = 0; i != 32; i = i + 1) begin
                    reg_file[i] <= 32'b0;
                end
                end else begin
                if (from_rs_rs1_flag) begin
                    to_rs_rs1_flag <= 1;
                    to_rs_index <= from_rs_index;
                    to_rs_rs1 <= reg_file[from_rs_rs1];
                end else begin
                    to_rs_rs1_flag <= 0;
                end

                if (from_rs_rs2_flag) begin
                    to_rs_rs2_flag <= 1;
                    to_rs_index <= from_rs_index;
                    to_rs_rs2 <= reg_file[from_rs_rs2];
                end else begin
                    to_rs_rs2_flag <= 0;
                end
                
                if (from_rob) begin
                    reg_file[from_rob_rd] <= from_rob_wdata;
                end
            end
        end
    end
    
    
endmodule // RegisterFile
