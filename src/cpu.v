// RISCV32 CPU top module
// port modification allowed for debugging purposes

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

  parameter CACHE_WIDTH = 5;
  parameter CACHE_SIZE = 32;
  parameter TAG_WIDTH = 16-CACHE_WIDTH;
  parameter IF_WIDTH = 5;
  parameter IF_SIZE = 32;
  parameter ROB_SIZE = 32;
  parameter ROB_WIDTH = 5;
  parameter RS_WIDTH = 5;
  parameter RS_SIZE = 32;
  parameter LSB_SIZE = 16;
  parameter LSB_WIDTH = 4;

  reg mem_wr_reg;
  reg [31:0] mem_a_reg;
  reg [7:0] mem_dout_reg;

  assign mem_wr = mem_wr_reg;
  assign mem_a = mem_a_reg;
  assign mem_dout = mem_dout_reg;

  // decoder outports wire
  wire                 	decoder_to_rs;
  wire [5:0]           	decoder_to_rs_op;
  wire [4:0]           	decoder_to_rs_rd;
  wire [4:0]           	decoder_to_rs_rs1;
  wire [4:0]           	decoder_to_rs_rs2;
  wire [31:0]          	decoder_to_rs_imm;
  wire [31:0]          	decoder_to_rs_pc;
  wire [31:0]          	decoder_to_rs_pc_next;
  wire [ROB_WIDTH-1:0] 	decoder_to_rs_tag;
  wire                 	decoder_to_lsb;
  wire [ROB_WIDTH-1:0] 	decoder_to_lsb_tag;
  wire                 	decoder_to_rob;

  // if outports wire
  wire        	if_mem_wr;
  wire [31:0] 	if_mem_a;
  wire        	if_to_decoder;
  wire [31:0] 	if_to_decoder_ins;
  wire [31:0] 	if_to_decoder_pc;
  wire [31:0] 	if_to_decoder_pc_next;

  // alu outports wire
  wire  alu_to_rs;
  wire [RS_WIDTH-1:0] alu_to_rs_index;
  wire [31:0] 	result;

  // lsb outports wire
  wire [7:0]    lsb_mem_dout;
  wire [31:0]   lsb_mem_a;
  wire          lsb_mem_wr;
  wire          lsb_to_if;
  wire          lsb_to_if_bsy;
  wire          lsb_to_rob;
  wire [31:0]   lsb_to_rob_data;
  wire [ROB_WIDTH-1:0]    lsb_to_rob_tag;

  // reg file outports wire
  wire regfile_to_rs_rs1_flag;
  wire regfile_to_rs_rs2_flag;
  wire [RS_WIDTH-1:0] regfile_to_rs_index;
  wire [31:0] regfile_to_rs_rs1;
  wire [31:0] regfile_to_rs_rs2;

  // rob outports wire
  wire          clear;
  wire          rob_to_if_bsy;
  wire          rob_to_reg_file;
  wire [4:0]    rob_to_reg_file_rd;
  wire [31:0]   rob_to_reg_file_wdata;
  wire          rob_to_lsb;
  wire [ROB_WIDTH-1:0] rob_to_lsb_tag;
  wire          rob_to_rs;
  wire          rob_to_rs_update;
  wire [ROB_WIDTH-1:0] rob_to_rs_update_order;
  wire [31:0]   rob_to_rs_update_wdata;
  wire [31:0]   rob_to_if_pc;

  
  // rs outports wire
  wire          rs_to_if_bsy;
  wire          rs_to_alu;
  wire [RS_WIDTH-1:0] rs_to_alu_index;
  wire [31:0]   rs_to_alu_a;
  wire [31:0]   rs_to_alu_b;
  wire [3:0]    rs_to_alu_op;
  wire          rs_to_reg_file_rs1_flag;
  wire          rs_to_reg_file_rs2_flag;
  wire [RS_WIDTH-1:0] rs_to_reg_file_index;
  wire [4:0]    rs_to_reg_file_rs1;
  wire [4:0]    rs_to_reg_file_rs2;
  wire          rs_to_rob;
  wire [RS_WIDTH-1:0] rs_to_rob_index;
  wire [ROB_WIDTH-1:0] rs_to_rob_tag;
  wire [2:0]    rs_to_rob_op;
  wire [4:0]    rs_to_rob_rd;
  wire [31:0]   rs_to_rob_wdata;
  wire [31:0]   rs_to_rob_jump;
  wire          rs_to_lsb;
  wire [3:0]    rs_to_lsb_op;
  wire [ROB_WIDTH-1:0]    rs_to_lsb_tag;
  wire [31:0]   rs_to_lsb_wdata;
  wire [31:0]   rs_to_lsb_address;


  Decoder #(
    .ROB_WIDTH 	( ROB_WIDTH  ))
  u_Decoder(
    .rst_in       	( rst_in        ),
    .clk_in       	( clk_in        ),
    .rdy_in       	( rdy_in        ),
    .clear        	( clear         ),
    .from_if      	( if_to_decoder       ),
    .pc           	( if_to_decoder_pc            ),
    .pc_next     	( if_to_decoder_pc_next ),
    .instruction  	( if_to_decoder_ins   ),
    .to_rs        	( decoder_to_rs         ),
    .to_rs_op     	( decoder_to_rs_op      ),
    .to_rs_rd     	( decoder_to_rs_rd      ),
    .to_rs_rs1    	( decoder_to_rs_rs1     ),
    .to_rs_rs2    	( decoder_to_rs_rs2     ),
    .to_rs_imm    	( decoder_to_rs_imm     ),
    .to_rs_pc     	( decoder_to_rs_pc      ),
    .to_rs_pc_next	( decoder_to_rs_pc_next ),
    .to_rs_tag    	( decoder_to_rs_tag     ),
    .to_lsb       	( decoder_to_lsb        ),
    .to_lsb_tag   	( decoder_to_lsb_tag    ),
    .to_rob       	( decoder_to_rob        )
  );
  
  IF #(
    .IF_WIDTH 	( IF_WIDTH  ),
    .IF_SIZE  	( IF_SIZE   ),
    .CACHE_WIDTH 	( CACHE_WIDTH  ),
    .CACHE_SIZE  	( CACHE_SIZE  ),
    .TAG_WIDTH  	( TAG_WIDTH   ))
  u_IF(
    .rst_in         	( rst_in          ),
    .clk_in         	( clk_in          ),
    .rdy_in         	( rdy_in          ),
    .clear          	( clear           ),
    .mem_din        	( mem_din         ),
    .from_lsb       	( lsb_to_if        ),
    .from_rob_jump  	( rob_to_if_pc   ),
    .from_lsb_bsy  	  ( lsb_to_if_bsy      ),
    .from_rs_bsy      	( rs_to_if_bsy     ),
    .from_rob_bsy      	( rob_to_if_bsy     ),
    .mem_wr         	( if_mem_wr          ),
    .mem_a          	( if_mem_a           ),
    .to_decoder     	( if_to_decoder      ),
    .to_decoder_ins 	( if_to_decoder_ins  ),
    .to_decoder_pc  	( if_to_decoder_pc   ),
    .to_decoder_pc_next	( if_to_decoder_pc_next )
  );
    
  ALU #(
    .ROB_WIDTH 	( ROB_WIDTH  ),
    .RS_WIDTH  	( RS_WIDTH   )) 
  u_ALU(
    .clk_in  	( clk_in   ),
    .rst_in  	( rst_in   ),
    .rdy_in  	( rdy_in   ),
    .clear   	( clear    ),
    .cal     	( rs_to_alu      ),
    .a       	( rs_to_alu_a        ),
    .b       	( rs_to_alu_b        ),
    .from_rs_index  ( rs_to_alu_index   ),
    .alu_op  	( rs_to_alu_op   ),
    .to_rs    ( alu_to_rs     ),
    .to_rs_index ( alu_to_rs_index  ),
    .result  	( result   )
  );

  Lsb #(
    .LSB_SIZE   ( LSB_SIZE ),
    .LSB_WIDTH  ( LSB_WIDTH ),
    .ROB_WIDTH  ( ROB_WIDTH ))
  u_Lsb(
    .rst_in          ( rst_in          ),
    .clk_in          ( clk_in          ),
    .rdy_in          ( rdy_in          ),
    .clear           ( clear           ),
    .from_decoder    ( decoder_to_lsb    ),
    .from_decoder_tag( decoder_to_lsb_tag),
    .from_rs         ( rs_to_lsb         ),
    .from_rs_op      ( rs_to_lsb_op     ),
    .from_rs_tag     ( rs_to_lsb_tag     ),
    .from_rs_wdata   ( rs_to_lsb_wdata   ),
    .from_rs_address ( rs_to_lsb_address ),
    .from_rob        ( rob_to_lsb        ),
    .from_rob_tag    ( rob_to_lsb_tag    ),
    .io_buffer_full  	( 1'b0   ),
    .mem_din         ( mem_din         ),
    .mem_dout        ( lsb_mem_dout        ),
    .mem_a           ( lsb_mem_a           ),
    .mem_wr          ( lsb_mem_wr          ),
    .to_if           ( lsb_to_if           ),
    .to_if_bsy      ( lsb_to_if_bsy      ),
    .to_rob          ( lsb_to_rob          ),
    .to_rob_tag      ( lsb_to_rob_tag      ),
    .to_rob_data     ( lsb_to_rob_data     )
  );

  RegisterFile #(
    .RS_WIDTH 	( RS_WIDTH  ))
  u_RegisterFile(
    .rst_in         ( rst_in         ),
    .clk_in         ( clk_in         ),
    .rdy_in         ( rdy_in         ),
    .from_rs_rs1_flag  ( rs_to_reg_file_rs1_flag),
    .from_rs_rs2_flag  ( rs_to_reg_file_rs2_flag),
    .from_rs_index  ( rs_to_reg_file_index  ),
    .from_rs_rs1    ( rs_to_reg_file_rs1    ),
    .from_rs_rs2    ( rs_to_reg_file_rs2    ),
    .from_rob       ( rob_to_reg_file       ),
    .from_rob_rd    ( rob_to_reg_file_rd    ),
    .from_rob_wdata ( rob_to_reg_file_wdata ),
    .to_rs_rs1_flag ( regfile_to_rs_rs1_flag),
    .to_rs_rs2_flag ( regfile_to_rs_rs2_flag),
    .to_rs_index    ( regfile_to_rs_index    ),
    .to_rs_rs1      ( regfile_to_rs_rs1      ),
    .to_rs_rs2      ( regfile_to_rs_rs2      )
  );

  rob #(
    .ROB_WIDTH  ( ROB_WIDTH ),
    .ROB_SIZE   ( ROB_SIZE ),
    .RS_WIDTH   ( RS_WIDTH ))
  u_rob(
    .rst_in            ( rst_in            ),
    .clk_in            ( clk_in            ),
    .rdy_in            ( rdy_in            ),
    .from_decoder      ( decoder_to_rob      ),
    .from_rs           ( rs_to_rob           ),
    .from_rs_tag       ( rs_to_rob_tag       ),
    .from_rs_op        ( rs_to_rob_op        ),
    .from_rs_rd        ( rs_to_rob_rd        ),
    .from_rs_wdata     ( rs_to_rob_wdata     ),
    .from_rs_jump      ( rs_to_rob_jump      ),
    .from_lsb          ( lsb_to_rob          ),
    .from_lsb_tag       ( lsb_to_rob_tag       ),
    .from_lsb_wdata   ( lsb_to_rob_data   ),
    .clear             ( clear             ),
    .to_if_bsy        ( rob_to_if_bsy        ),
    .to_reg_file       ( rob_to_reg_file       ),
    .to_reg_file_rd    ( rob_to_reg_file_rd    ),
    .to_reg_file_wdata ( rob_to_reg_file_wdata ),
    .to_lsb            ( rob_to_lsb            ),
    .to_lsb_tag        ( rob_to_lsb_tag        ),
    .to_rs             ( rob_to_rs             ),
    .to_rs_update      ( rob_to_rs_update      ),
    .to_rs_update_order( rob_to_rs_update_order),
    .to_rs_update_wdata( rob_to_rs_update_wdata),
    .to_if_pc          ( rob_to_if_pc          )
  );

  rs #(
    .ROB_WIDTH  ( ROB_WIDTH ),
    .RS_SIZE    ( RS_SIZE ),
    .RS_WIDTH   ( RS_WIDTH ))
  u_rs(
    .rst_in              ( rst_in              ),
    .clk_in              ( clk_in              ),
    .rdy_in              ( rdy_in              ),
    .clear               ( clear               ),
    .from_decoder        ( decoder_to_rs        ),
    .from_decoder_op     ( decoder_to_rs_op     ),
    .from_decoder_rd     ( decoder_to_rs_rd     ),
    .from_decoder_rs1    ( decoder_to_rs_rs1    ),
    .from_decoder_rs2    ( decoder_to_rs_rs2    ),
    .from_decoder_imm    ( decoder_to_rs_imm    ),
    .from_decoder_pc     ( decoder_to_rs_pc     ),
    .from_decoder_pc_next ( decoder_to_rs_pc_next ),
    .from_decoder_tag    ( decoder_to_rs_tag    ),
    .from_reg_file_rs1_flag ( regfile_to_rs_rs1_flag),
    .from_reg_file_rs2_flag ( regfile_to_rs_rs2_flag),
    .from_reg_file_index ( regfile_to_rs_index ),
    .from_reg_file_rs1   ( regfile_to_rs_rs1   ),
    .from_reg_file_rs2   ( regfile_to_rs_rs2   ),
    .from_alu            ( alu_to_rs            ),
    .from_alu_index     ( alu_to_rs_index     ),
    .from_alu_result     ( result     ),
    .from_rob            ( rob_to_rs            ),
    .from_rob_update     ( rob_to_rs_update     ),
    .from_rob_update_order ( rob_to_rs_update_order ),
    .from_rob_update_wdata ( rob_to_rs_update_wdata ),
    .to_if_bsy          ( rs_to_if_bsy          ),
    .to_alu              ( rs_to_alu              ),
    .to_alu_index       ( rs_to_alu_index       ),
    .to_alu_a            ( rs_to_alu_a            ),
    .to_alu_b            ( rs_to_alu_b            ),
    .to_alu_op           ( rs_to_alu_op           ),
    .to_reg_file_rs1_flag( rs_to_reg_file_rs1_flag),
    .to_reg_file_rs2_flag( rs_to_reg_file_rs2_flag),
    .to_reg_file_index   ( rs_to_reg_file_index  ),
    .to_reg_file_rs1     ( rs_to_reg_file_rs1     ),
    .to_reg_file_rs2     ( rs_to_reg_file_rs2     ),
    .to_rob              ( rs_to_rob              ),
    .to_rob_index        ( rs_to_rob_index        ),
    .to_rob_tag          ( rs_to_rob_tag          ),
    .to_rob_op           ( rs_to_rob_op           ),
    .to_rob_rd           ( rs_to_rob_rd           ),
    .to_rob_wdata        ( rs_to_rob_wdata        ),
    .to_rob_jump         ( rs_to_rob_jump         ),
    .to_lsb              ( rs_to_lsb              ),
    .to_lsb_op           ( rs_to_lsb_op           ),
    .to_lsb_tag           ( rs_to_lsb_tag           ),
    .to_lsb_wdata        ( rs_to_lsb_wdata        ),
    .to_lsb_address      ( rs_to_lsb_address      )
  );

  always@(*)begin
    if (!lsb_to_if) begin
      mem_wr_reg = if_mem_wr;
      mem_a_reg = if_mem_a;
      mem_dout_reg = 8'b0;
    end else begin
      mem_wr_reg = lsb_mem_wr;
      mem_a_reg = lsb_mem_a;
      mem_dout_reg = lsb_mem_dout;
    end
  end

endmodule