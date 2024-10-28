module RegisterFile (input rst_in,
                     input clk_in,
                     input rdy_in,
                     input from_rs,
                     input [4:0] from_rs_rs1,
                     input [4:0] from_rs_rs2,
                     input from_lsb,
                     input from_lsb_rw,               // 0 for read, 1 for write
                     input [4:0] from_lsb_rd,
                     input [4:0] from_lsb_rs1,
                     input [31:0] from_lsb_wdata,
                     output reg [31:0] to_rs_rs1,
                     output reg [31:0] to_rs_rs2,
                     output reg [31:0] to_lsb_rd_rs1,
                     );
    reg [31:0] reg_file [0:31];
    
    always_ff @(posedge clk_in or posedge rst_in) begin
        if (rst_in) begin
            for (int i = 0; i < 32; i++) begin
                reg_file[i] <= 32'b0;
            end
            end else  begin
            if (from_rs) begin
                to_rs_rs1 <= reg_file[from_rs_rs1];
                to_rs_rs2 <= reg_file[from_rs_rs2];
            end
            else if (from_lsb) begin
                if (from_lsb_rw) begin
                    reg_file[from_lsb_rd] <= from_lsb_wdata;
                    end else begin
                    to_lsb_rs1 <= reg_file[from_lsb_rs1];
                end
            end
                end
                end
                
                
                endmodule // RegisterFile
