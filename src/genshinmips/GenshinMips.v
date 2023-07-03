`include "define.v"

/*顶层模块*/

module GenshinMIPS(
    input wire                  rst,
    input wire                  clk,

    //连接到指令存储器
    input wire [`RegBus]        rom_data_i, //从指令存储器取得的指令
    output wire [`RegBus]       rom_addr_o, //输出到指令存储器的地址
    output wire                 rom_ce_o,   //指令存储器使能

    //连接数据存储器data_ram
	input wire [`RegBus]        ram_data_i,
	output wire [`RegBus]       ram_addr_o,
	output wire [`RegBus]       ram_data_o,
	output wire                 ram_we_o,
	output wire [3:0]           ram_sel_o,
	output wire                 ram_ce_o,

    input  wire [1:0]           state
);

//连接IF/ID模块与译码阶段ID模块的变量
wire [`InstAddrBus]             pc;
wire [`InstAddrBus]             id_pc_i;
wire [`InstBus]                 id_inst_i;

//连接译码阶段ID模块输出与ID/EX模块输入的变量
wire [`AluOpBus]                id_aluop_o;
wire [`AluSelBus]               id_alusel_o;
wire [`RegBus]                  id_reg1_o;
wire [`RegBus]                  id_reg2_o;
wire                            id_wreg_o;
wire [`RegAddrBus]              id_wd_o;
wire                            id_is_in_delayslot_o;
wire [`RegBus]                  id_link_address_o;	
wire [`RegBus]                  id_inst_o;

//连接ID/EX模块输出与执行阶段EX模块输入的变量
wire [`AluOpBus]                ex_aluop_i;
wire [`AluSelBus]               ex_alusel_i;
wire [`RegBus]                  ex_reg1_i;
wire [`RegBus]                  ex_reg2_i;
wire                            ex_wreg_i;
wire [`RegAddrBus]              ex_wd_i;
wire                            ex_is_in_delayslot_i;	
wire [`RegBus]                  ex_link_address_i;	
wire [`RegBus]                  ex_inst_i;

//连接执行阶段EX模块输出与EX/MEM模块的输入的变量
wire                            ex_wreg_o;
wire [`RegAddrBus]              ex_wd_o;
wire [`RegBus]                  ex_wdata_o;
wire [`AluOpBus]                ex_aluop_o;
wire [`RegBus]                  ex_mem_addr_o;
wire [`RegBus]                  ex_reg1_o;
wire [`RegBus]                  ex_reg2_o;

//连接EX/MEM模块输出与访存阶段MEM模块输入的变量
wire                            mem_wreg_i;
wire [`RegAddrBus]              mem_wd_i;
wire [`RegBus]                  mem_wdata_i;
wire [`AluOpBus]                mem_aluop_i;
wire [`RegBus]                  mem_mem_addr_i;
wire [`RegBus]                  mem_reg1_i;
wire [`RegBus]                  mem_reg2_i;


//连接访存阶段MEM模块的输出与MEM/WB模块的输入
wire                            mem_wreg_o;
wire[`RegAddrBus]               mem_wd_o;
wire[`RegBus]                   mem_wdata_o;

//连接MEM/WB模块输出与回写阶段输入的变量
wire                            wb_wreg_i;
wire [`RegAddrBus]              wb_wd_i;
wire [`RegBus]                  wb_wdata_i;

//连接译码阶段ID模块与通用寄存器Regfile模块的变量
wire                            reg1_read;
wire                            reg2_read;
wire [`RegBus]                  reg1_data;
wire [`RegBus]                  reg2_data;
wire [`RegAddrBus]              reg1_addr;
wire [`RegAddrBus]              reg2_addr;

//连接EX与ID模块的变量
wire [`DataBus]                 ex_id_last_sdata;
wire [`DataAddrBus]             ex_id_last_saddr;

wire                            is_in_delayslot_i;
wire                            is_in_delayslot_o;
wire                            next_inst_in_delayslot_o;
wire                            id_branch_flag_o;
wire [`RegBus]                  branch_target_address;

wire[5:0] stall;
wire stallreq_from_id;	
wire stallreq_from_mem;

/*各模块实例化*/

pc_reg pc_reg0(
    .clk(clk),
    .rst(rst),
    .pc(pc),
    .stall(stall),
    .branch_flag_i(id_branch_flag_o),
    .branch_target_address_i(branch_target_address),

    .ce(rom_ce_o)	
);

assign rom_addr_o = pc;

if_id if_id0(
    .clk(clk), 
    .rst(rst),
    .stall(stall),       
    .if_pc(pc), 
    .if_inst(rom_data_i),       
    .id_pc(id_pc_i),
    .id_inst(id_inst_i)
);

id id0(
    .rst(rst), 
    .pc_i(id_pc_i),  
    .inst_i(id_inst_i),

    //来自执行阶段的结果
    .ex_wd_i(ex_wd_o),
    .ex_wdata_i(ex_wdata_o),
    .ex_wreg_i(ex_wreg_o),
    .ex_aluop_i(ex_aluop_o),

    //来自访存阶段的结果
    .mem_wd_i(mem_wd_o),
    .mem_wdata_i(mem_wdata_o),
    .mem_wreg_i(mem_wreg_o),

    //来自Regfile模块的输入
    .reg1_data_i(reg1_data),
    .reg2_data_i(reg2_data),

    .is_in_delayslot_i(is_in_delayslot_i),

    //送到Regfile模块的信息
    .reg1_read_o(reg1_read),    
    .reg2_read_o(reg2_read),

    .reg1_addr_o(reg1_addr),    
    .reg2_addr_o(reg2_addr),

    //送到ID/EX模块的信息
    .aluop_o(id_aluop_o),       
    .alusel_o(id_alusel_o),
    .reg1_o(id_reg1_o),         
    .reg2_o(id_reg2_o),
    .wd_o(id_wd_o),             
    .wreg_o(id_wreg_o),
    .inst_o(id_inst_o),

    .next_inst_in_delayslot_o(next_inst_in_delayslot_o),	
    .branch_flag_o(id_branch_flag_o),
    .branch_target_address_o(branch_target_address),       
    .link_addr_o(id_link_address_o),
    
    .is_in_delayslot_o(id_is_in_delayslot_o),

    //EX阶段存储加载信息
    .ex_last_saddr_i(ex_id_last_saddr),
    .ex_last_sdata_i(ex_id_last_sdata),    
    .ex_last_laddr_i(ex_wreg_o),    

    .stallreq(stallreq_from_id),

    .state(state)
);

regfile regfile1(
    .clk (clk),
    .rst (rst),
    .we	(wb_wreg_i),
    .waddr (wb_wd_i),
    .wdata (wb_wdata_i),
    .re1 (reg1_read),
    .raddr1 (reg1_addr),
    .rdata1 (reg1_data),
    .re2 (reg2_read),
    .raddr2 (reg2_addr),
    .rdata2 (reg2_data)
);

id_ex id_ex0(
    .clk(clk),                  
    .rst(rst),
    .stall(stall), 

    //从译码阶段ID模块传递来的信息
    .id_aluop(id_aluop_o),      
    .id_alusel(id_alusel_o),
    .id_reg1(id_reg1_o),        
    .id_reg2(id_reg2_o),
    .id_wd(id_wd_o),            
    .id_wreg(id_wreg_o),
    .id_link_address(id_link_address_o),
    .id_is_in_delayslot(id_is_in_delayslot_o),
    .next_inst_in_delayslot_i(next_inst_in_delayslot_o),
    .id_inst(id_inst_o),

    //传递到执行阶段EX模块的信息
    .ex_aluop(ex_aluop_i),      
    .ex_alusel(ex_alusel_i),
    .ex_reg1(ex_reg1_i),        
    .ex_reg2(ex_reg2_i),
    .ex_wd(ex_wd_i),            
    .ex_wreg(ex_wreg_i),
    .ex_link_address(ex_link_address_i),
  	.ex_is_in_delayslot(ex_is_in_delayslot_i),
    .is_in_delayslot_o(is_in_delayslot_i),
    .ex_inst(ex_inst_i)	
);

ex ex0(
    .rst(rst),

    //从ID/EX模块传递来的信息
    .aluop_i(ex_aluop_i),       
    .alusel_i(ex_alusel_i),
    .reg1_i(ex_reg1_i),         
    .reg2_i(ex_reg2_i),
    .wd_i(ex_wd_i),             
    .wreg_i(ex_wreg_i),
    .inst_i(ex_inst_i),

    .link_address_i(ex_link_address_i),
    .is_in_delayslot_i(ex_is_in_delayslot_i),	

    //输出到EX/MEM模块的信息（包含前推到译码阶段）
    .wd_o(ex_wd_o),             
    .wreg_o(ex_wreg_o),
    .wdata_o(ex_wdata_o),
    
    .aluop_o(ex_aluop_o),
    .mem_addr_o(ex_mem_addr_o),
    .reg2_o(ex_reg2_o)

    // .stallreq(stallreq_from_mem) 
);

ex_mem ex_mem0(
    .clk(clk),                  
    .rst(rst),
    .stall(stall), 

    //来自执行阶段EX模块的信息
    .ex_wd(ex_wd_o),            
    .ex_wreg(ex_wreg_o),
    .ex_wdata(ex_wdata_o),

    .ex_aluop(ex_aluop_o),
    .ex_mem_addr(ex_mem_addr_o),
    .ex_reg2(ex_reg2_o),

    //送到访存阶段MEM模块的信息
    .mem_wd(mem_wd_i),          
    .mem_wreg(mem_wreg_i),
    .mem_wdata(mem_wdata_i),

    .mem_aluop(mem_aluop_i),
    .mem_mem_addr(mem_mem_addr_i),
    .mem_reg2(mem_reg2_i)
);

mem mem0(
    .rst(rst),

    //来自memory的信息
    .mem_data_i(ram_data_i),

    //来自EX/MEM模块的信息	
    .wd_i(mem_wd_i),
    .wreg_i(mem_wreg_i),
    .wdata_i(mem_wdata_i),

    .aluop_i(mem_aluop_i),
    .mem_addr_i(mem_mem_addr_i),
    .reg2_i(mem_reg2_i),
    
    //送到MEM/WB模块的信息（包含前推到译码阶段）
    .wd_o(mem_wd_o),
    .wreg_o(mem_wreg_o),
    .wdata_o(mem_wdata_o),

    //送到memory的信息
    .mem_addr_o(ram_addr_o),
    .mem_we_o(ram_we_o),
    .mem_sel_o(ram_sel_o),
    .mem_data_o(ram_data_o),
    .mem_ce_o(ram_ce_o),

    .stallreq(stallreq_from_mem)	
);

mem_wb mem_wb0(
    .clk(clk),
    .rst(rst),
    .stall(stall), 

    //来自访存阶段MEM模块的信息	
    .mem_wd(mem_wd_o),
    .mem_wreg(mem_wreg_o),
    .mem_wdata(mem_wdata_o),

    //送到回写阶段的信息
    .wb_wd(wb_wd_i),
    .wb_wreg(wb_wreg_i),
    .wb_wdata(wb_wdata_i)
                                        
);

ctrl ctrl0(
    .rst(rst),
    .stallreq_from_id(stallreq_from_id),

  	//来自执行阶段的暂停请求
    .stallreq_from_mem(stallreq_from_mem),

    .stall(stall)       	
);
endmodule