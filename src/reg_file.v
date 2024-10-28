module RegisterFile (input logic clk,
                     input logic reset,
                     input logic [4:0] ra1,
                     input logic [4:0] ra2,
                     input logic [4:0] wa,
                     input logic we,
                     input logic [31:0] wd,
                     output logic [31:0] rd1,
                     output logic [31:0] rd2);
    logic [31:0] reg_file [0:31];
    
    // 重置时清空所有寄存器
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 32; i++) begin
                reg_file[i] <= 32'b0;
            end
            end else if (we) begin
            reg_file[wa] <= wd;
        end
    end
    
    always_comb begin
        rd1 = (ra1 == 5'b0) ? 32'b0 : reg_file[ra1];
        rd2 = (ra2 == 5'b0) ? 32'b0 : reg_file[ra2];
    end
    
endmodule // RegisterFile
