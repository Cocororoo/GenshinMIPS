`include "define.v"

/*顶层模块*/

module genshinmips(
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

wire[5:0] stall;
wire stallreq_from_id;	
wire stallreq_from_mem;

/****************************************
*               IF级                    *
*****************************************/

wire                            id_if_branch_flag;
wire [`RegBus]                  id_if_branch_target_address;
wire [`InstAddrBus]             pc;

pc_reg pc_reg0(
    .clk(clk),
    .rst(rst),

    .pc(rom_addr_o),
    .stall(stall),
    
    .branch_flag_i(id_if_branch_flag),
    .branch_target_address_i(id_if_branch_target_address),

    .ce(rom_ce_o)	
);


//连接IF/ID模块与译码阶段ID模块的变量
wire [`InstAddrBus]             if_id_pc;
wire [`InstBus]                 if_id_inst;

if_id if_id0(
    .clk(clk), 
    .rst(rst),

    .if_pc(rom_addr_o), 
    .if_inst(rom_data_i),

    .id_pc(if_id_pc),
    .id_inst(if_id_inst),

    .stall(stall)
);

wire [`InstAddrBus]             mem_wb_debug_pc;

/****************************************
*               ID级                    *
*****************************************/

//连接译码阶段ID模块与通用寄存器Regfile模块的变量
wire                            id_rf_reg1_re;
wire                            id_rf_reg2_re;
wire [`RegBus]                  reg1_data;
wire [`RegBus]                  reg2_data;
wire [`RegAddrBus]              id_rf_reg1_raddr;
wire [`RegAddrBus]              id_rf_reg2_raddr;

//连接译码阶段ID模块输出与ID/EX模块输入的变量
wire [`AluOpBus]                id_aluop_o;
wire [`RegBus]                  id_reg1_data_o;
wire [`RegBus]                  id_reg2_data_o;
wire                            id_we_o;
wire [`RegAddrBus]              id_waddr_o;
wire                            id_is_in_delayslot_o;
wire [`RegBus]                  id_link_address_o;	
wire [`RegBus]                  id_inst_o;

//连接EX模块的输出与EX/MEM模块的输入--->数据前推：EX阶段前推
wire                            ex_we_o;
wire [`RegAddrBus]              ex_waddr_o;
wire [`RegBus]                  ex_wdata_o;
wire [`AluOpBus]                ex_aluop_o;
wire [`RegBus]                  ex_mem_addr_o;  //访存要写入的地址
wire [`RegBus]                  ex_mem_data_o; //访存要写入的数据

//连接MEM模块的输出与MEM/WB模块的输入--->数据前推：MEM阶段前推
wire                            mem_we_o;
wire[`RegAddrBus]               mem_waddr_o;
wire[`RegBus]                   mem_wdata_o;

//连接EX与ID模块的变量（数据前推）
wire [`DataBus]                 ex_id_last_sdata;
wire [`DataAddrBus]             ex_id_last_saddr;


id id0(
    .rst(rst), 
    .id_pc_i(if_id_pc),  
    .inst_i(if_id_inst),


    //来自Regfile模块的输入
    .reg1_data_i(reg1_data),
    .reg2_data_i(reg2_data),

    //送到Regfile模块的信息
    .reg1_re_o(id_rf_reg1_re),    
    .reg2_re_o(id_rf_reg2_re),

    .reg1_raddr_o(id_rf_reg1_raddr),    
    .reg2_raddr_o(id_rf_reg2_raddr),

    //来自EX阶段的结果
    .ex_waddr_i(ex_waddr_o),
    .ex_wdata_i(ex_wdata_o),
    .ex_we_i(ex_we_o),
    .ex_aluop_i(ex_aluop_o),

    //来自MEM阶段的结果
    .mem_waddr_i(mem_waddr_o),
    .mem_wdata(mem_wdata_o),
    .mem_we_i(mem_we_o),

    //送到ID/EX模块的信息
    .aluop_o(id_aluop_o),       
    .reg1_data_o(id_reg1_data_o),         
    .reg2_data_o(id_reg2_data_o),
    .waddr_o(id_waddr_o),             
    .we_o(id_we_o),
    .inst_o(id_inst_o),
	
    .branch_flag_o(id_if_branch_flag),
    .branch_target_address_o(id_if_branch_target_address),       
    .link_addr_o(id_link_address_o),
    

    //EX阶段存储加载信息
    .ex_last_saddr_i(ex_id_last_saddr),
    .ex_last_sdata_i(ex_id_last_sdata),    
    .ex_last_laddr_i(ex_mem_addr_o),    

    .stallreq(stallreq_from_id)

);

//连接ID/EX模块输出与执行阶段EX模块输入的变量
wire [`AluOpBus]                id_ex_aluop;
wire [`RegBus]                  id_ex_reg1_data;
wire [`RegBus]                  id_ex_reg2_data;
wire                            id_ex_we;
wire [`RegAddrBus]              id_ex_waddr;
wire [`RegBus]                  id_ex_link_addr;	
wire [`RegBus]                  id_ex_inst;

wire [`InstAddrBus]             id_ex_debug_pc;

id_ex id_ex0(
    .clk(clk),                  
    .rst(rst),
    .stall(stall), 
    .debug_pc_i(if_id_pc),
    .debug_pc_o(id_ex_debug_pc),

    //从译码阶段ID模块传递来的信息
    .id_aluop(id_aluop_o),      
    .id_reg1_data(id_reg1_data_o),        
    .id_reg2_data(id_reg2_data_o),
    .id_waddr(id_waddr_o),            
    .id_we(id_we_o),
    .id_link_addr(id_link_address_o),
    .id_inst(id_inst_o),

    //传递到执行阶段EX模块的信息
    .ex_aluop(id_ex_aluop),      
    .ex_alusel(id_ex_alusel),
    .ex_reg1_data(id_ex_reg1_data),        
    .ex_reg2_data(id_ex_reg2_data),
    .ex_waddr(id_ex_waddr),
    .ex_we(id_ex_we),            
    .ex_link_addr(id_ex_link_addr),
    .ex_inst(id_ex_inst)	
);

/****************************************
*               EX级                    *
*****************************************/

ex ex0(
    .rst(rst),
    .debug_pc(id_ex_debug_pc),

    //从ID/EX模块传递来的信息
    .aluop_i(id_ex_aluop),       
    .alusel_i(id_ex_alusel),
    .reg1_i(id_ex_reg1_data),         
    .reg2_i(id_ex_reg2_data),
    .waddr_i(id_ex_waddr),             
    .inst_i(id_ex_inst),
    .we_i(id_ex_we),

    .link_addr_i(id_ex_link_addr),

    //输出到EX/MEM模块的信息（包含前推到译码阶段）
    .waddr_o(ex_waddr_o),             
    .we_o(ex_we_o),
    .wdata_o(ex_wdata_o),
    
    .aluop_o(ex_aluop_o),
    .mem_addr_o(ex_mem_addr_o),
    .mem_data_o(ex_mem_data_o)

    // .stallreq(stallreq_from_mem) 
);

wire [`InstAddrBus] ex_mem_debug_pc;

//连接EX/MEM模块输出与访存阶段MEM模块输入的变量
wire                            ex_mem_we;
wire [`RegAddrBus]              ex_mem_waddr;
wire [`RegBus]                  ex_mem_wdata;
wire [`AluOpBus]                ex_mem_aluop;
wire [`RegBus]                  mem_mem_addr;
wire [`RegBus]                  mem_mem_data;     //访存要写入的数据

ex_mem ex_mem0(
    .clk(clk),                  
    .rst(rst),
    .stall(stall), 
    .debug_pc_i(id_ex_debug_pc),
    .debug_pc_o(ex_mem_debug_pc),

    //来自执行阶段EX模块的信息
    .ex_waddr(ex_waddr_o),            
    .ex_we(ex_we_o),
    .ex_wdata(ex_wdata_o),

    .ex_aluop(ex_aluop_o),
    .ex_mem_addr(ex_mem_addr_o),
    .ex_mem_data(ex_mem_data_o),

    //送到访存阶段MEM模块的信息
    .mem_waddr(ex_mem_waddr),          
    .mem_we(ex_mem_we),
    .mem_wdata(ex_mem_wdata),

    .mem_aluop(ex_mem_aluop),
    .mem_mem_addr(mem_mem_addr),
    .mem_mem_data(mem_mem_data),

    .id_last_sdata_o(ex_id_last_sdata),
    .id_last_saddr_o(ex_id_last_saddr)
);


/****************************************
*              MEM级                    *
*****************************************/

mem mem0(
    .rst(rst),
    .debug_pc_i(ex_mem_debug_pc),

    //来自memory的信息
    .ram_data_i(ram_data_i),

    //来自EX/MEM模块的信息	
    .waddr_i(ex_mem_waddr),
    .we_i(ex_mem_we),
    .wdata_i(ex_mem_wdata),

    .aluop_i(ex_mem_aluop),
    .mem_addr_i(mem_mem_addr),
    .mem_data_i(mem_mem_data),
    
    //送到MEM/WB模块的信息（包含前推到译码阶段）
    .waddr_o(mem_waddr_o),
    .we_o(mem_we_o),
    .wdata_o(mem_wdata_o),

    //送到memory的信息
    .mem_addr_o(ram_addr_o),
    .mem_we_o(ram_we_o),
    .mem_sel_o(ram_sel_o),
    .mem_data_o(ram_data_o),
    .mem_ce_o(ram_ce_o),

    .stallreq(stallreq_from_mem)	
);

//连接MEM/WB模块输出与回写阶段输入的变量
wire                            wb_we_i;
wire [`RegAddrBus]              wb_waddr_i;
wire [`RegBus]                  wb_wdata_i;


mem_wb mem_wb0(
    .clk(clk),
    .rst(rst),
    .stall(stall), 
    .debug_pc_i(ex_mem_debug_pc),
    .debug_pc_o(mem_wb_debug_pc),

    //来自访存阶段MEM模块的信息	
    .mem_wd(mem_waddr_o),
    .mem_wreg(mem_we_o),
    .mem_wdata(mem_wdata_o),

    //送到回写阶段的信息
    .wb_wd(wb_waddr_i),
    .wb_wreg(wb_we_i),
    .wb_wdata(wb_wdata_i)
                                        
);

regfile regfile1(
    .clk (clk),
    .rst (rst),
    .debug_pc_i(mem_wb_debug_pc),

    .we	(wb_we_i),
    .waddr (wb_waddr_i),
    .wdata (wb_wdata_i),

    .re1 (id_rf_reg1_re),
    .raddr1 (id_rf_reg1_raddr),
    .rdata1 (reg1_data),
    
    .re2 (id_rf_reg2_re),
    .raddr2 (id_rf_reg2_raddr),
    .rdata2 (reg2_data)
);

/****************************************
*           流水线暂停                  *
*****************************************/
ctrl ctrl0(
    .rst(rst),
    .stallreq_from_id(stallreq_from_id),

  	//来自执行阶段的暂停请求
    .stallreq_from_mem(stallreq_from_mem),

    .stall(stall)       	
);
endmodule