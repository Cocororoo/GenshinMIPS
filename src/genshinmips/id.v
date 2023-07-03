`include "define.v"

/*
* id模块：对指令译码，得到最终运算的类型、子类型、源操作数1、源操作数2、要写入的目的寄存器地址等
*/

module id(
    input wire                      rst,            
    input wire [`InstAddrBus]       pc_i,           //译码阶段指令对应地址
    input wire [`InstBus]           inst_i,         //译码阶段的指令

    //读取的Regfile值
    input wire [`RegBus]            reg1_data_i,
    input wire [`RegBus]            reg2_data_i,

    //数据前推实现：处于执行阶段指令的运算结果
    input wire                      ex_wreg_i,
    input wire [`RegBus]            ex_wdata_i,
    input wire [`RegAddrBus]        ex_wd_i,        //执行阶段写寄存器的地址

    //数据前推实现：处于访存阶段的指令运算结果
    input wire                      mem_wreg_i,
    input wire [`RegBus]            mem_wdata_i,
    input wire [`RegAddrBus]        mem_wd_i,

    //延迟槽指令（如果上一条指令是转移指令，下一条进入译码阶段的指令为延迟槽指令）
    input wire                      is_in_delayslot_i,

    //上一条指令是否会产生load相关
    input wire [`AluOpBus]          ex_aluop_i,

    //将指令码输出
    output wire [`RegBus]           inst_o,

    //输出到Regfile的信息
    output reg                      reg1_read_o,    //Regfile第一个读寄存器端口的读使能
    output reg                      reg2_read_o,    //Regfile第二个读寄存器端口的读使能
    output reg [`RegAddrBus]        reg1_addr_o,    //Regfile第一个读寄存器端口的地址
    output reg [`RegAddrBus]        reg2_addr_o,    //Regfile第二个读寄存器端口的地址
    
    //送到执行阶段的信息
    output reg [`AluOpBus]          aluop_o,        //译码阶段的指令要进行的运算子类型
    output reg [`AluSelBus]         alusel_o,       //译码阶段的指令要进行的运算类型
    output reg [`RegBus]            reg1_o,         //译码阶段的指令要进行的运算的源操作数1
    output reg [`RegBus]            reg2_o,         //译码阶段的指令要进行的运算的源操作数2
    output reg [`RegAddrBus]        wd_o,           //译码阶段的指令要写入的目的地寄存器地址
    output reg                      wreg_o,         //译码阶段的指令是否有要写入的目的寄存器
    
    //中断请求
    output wire                     stallreq,

    output reg                      next_inst_in_delayslot_o,

    output reg                      branch_flag_o,
    output reg [`RegBus]            branch_target_address_o,
    output reg [`RegBus]            link_addr_o,
    output reg                      is_in_delayslot_o,
    
    //load冒险处理
    // input  wire                     ex_last_is_load_i,  //上一条指令是否是Load
    input  wire [`DataAddrBus]      ex_last_laddr_i,    //上一次加载地址
    input  wire [`DataAddrBus]      ex_last_saddr_i,    //上一次存储地址
    input  wire [`DataBus]          ex_last_sdata_i,    //上一次存储数据
    
    input  wire                     state               //串口状态
);

    //要读的寄存器是否与上条指令存在load相关
    reg                             stallreq_for_reg1_loadrelate;
    reg                             stallreq_for_reg2_loadrelate;
    wire                            pre_inst_is_load;
    assign pre_inst_is_load = ((ex_aluop_i == `EXE_LB_OP) || 
                                (ex_aluop_i == `EXE_LW_OP)) ? 1'b1 : 1'b0;

    assign inst_o = inst_i;
    assign stallreq = stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;
    
    wire [`RegBus]                  pc_plus_8;
    wire [`RegBus]                  pc_plus_4;
    assign                          pc_plus_4 = pc_i + 4;
    assign                          pc_plus_8 = pc_i + 8;

    //分支指令中offset左移两位再符号拓展至32位
    wire [`RegBus]                  imm_sll2_signedext;
    assign                          imm_sll2_signedext = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};


    //取得指令的指令码、功能码
    wire [5:0]                      op  = inst_i[31:26];
    wire [4:0]                      op2 = inst_i[10: 6];
    wire [5:0]                      op3 = inst_i[5 : 0];
    wire [4:0]                      op4 = inst_i[20:16];

    //保存指令执行需要的立即数
    reg[`RegBus]                    imm;

    //指示指令是否有效
    reg                             instvalid;


    /*Part.1 对指令译码*/
    always @(*) begin
        if (rst == `RstEnable) begin
            aluop_o                 <= `EXE_NOP_OP;
            alusel_o                <= `EXE_RES_NOP;
            wd_o                    <= `NOPRegAddr;
            wreg_o                  <= `WriteDisable;
            instvalid               <= `InstValid;
            reg1_read_o             <= 1'b0;
            reg2_read_o             <= 1'b0;
            reg1_addr_o             <= `NOPRegAddr;
            reg2_addr_o             <= `NOPRegAddr;
            imm                     <= 32'h0;

            link_addr_o             <= `ZeroWord;
            branch_flag_o           <= `NotBranch;
            branch_target_address_o <= `ZeroWord;
            next_inst_in_delayslot_o<= `NotInDelaySlot;
        end else begin
            aluop_o                 <= `EXE_NOP_OP;
            alusel_o                <= `EXE_RES_NOP;
            wd_o                    <= inst_i[15:11];
            wreg_o                  <= `WriteDisable;
            instvalid               <= `InstInvalid;
            reg1_read_o             <= 1'b0;
            reg2_read_o             <= 1'b0;
            reg1_addr_o             <= inst_i[25:21];
            reg2_addr_o             <= inst_i[20:16];
            imm                     <= `ZeroWord;
        
            link_addr_o             <= `ZeroWord;
            branch_flag_o           <= `NotBranch;
            branch_target_address_o <= `ZeroWord;
            next_inst_in_delayslot_o<= `NotInDelaySlot;

            case (op)   //依据op取值判断指令
                `EXE_SPECIAL_INST: begin            //指令码是SPECIAL
                    case (op2)
                        5'b00000: begin
                            case (op3)
                                `EXE_OR: begin      //or指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_OR_OP;
                                    alusel_o        <= `EXE_RES_LOGIC;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_AND: begin     //and指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_AND_OP;
                                    alusel_o        <= `EXE_RES_LOGIC;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_XOR: begin     //xor指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_XOR_OP;
                                    alusel_o        <= `EXE_RES_LOGIC;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_NOR: begin     //nor指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_NOR_OP;
                                    alusel_o        <= `EXE_RES_LOGIC;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_SLLV: begin     //sllv指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_SLL_OP;
                                    alusel_o        <= `EXE_RES_SHIFT;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_SRLV: begin     //srlv指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_SRL_OP;
                                    alusel_o        <= `EXE_RES_SHIFT;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_SRAV: begin     //srav指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_SRA_OP;
                                    alusel_o        <= `EXE_RES_SHIFT;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end

                                `EXE_SLT: begin      // slt指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_SLT_OP;
                                    alusel_o        <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_SLTU: begin     // sltu指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_SLTU_OP;
                                    alusel_o        <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_ADD: begin     // add指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_ADD_OP;
                                    alusel_o        <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_ADDU: begin    // addu指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_ADDU_OP;
                                    alusel_o        <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_SUB: begin     // sub指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_SUB_OP;
                                    alusel_o        <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                `EXE_SUBU: begin    // subu指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_SUBU_OP;
                                    alusel_o        <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b1;
                                    instvalid       <= `InstValid;
                                end
                                
                                `EXE_JR: begin      // jr指令
                                    wreg_o          <= `WriteDisable;
                                    aluop_o         <= `EXE_JR_OP;
                                    alusel_o        <= `EXE_RES_JUMP_BRANCH;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b0;
                                    instvalid       <= `InstValid;
                                    link_addr_o             <= `ZeroWord;
                                    branch_flag_o           <= `Branch;
                                    branch_target_address_o <= reg1_o;
                                    next_inst_in_delayslot_o<= `InDelaySlot;
                                end
                                `EXE_JALR: begin    // jalr指令
                                    wreg_o          <= `WriteEnable;
                                    aluop_o         <= `EXE_JALR_OP;
                                    alusel_o        <= `EXE_RES_JUMP_BRANCH;
                                    reg1_read_o     <= 1'b1;
                                    reg2_read_o     <= 1'b0;
                                    instvalid       <= `InstValid;
                                    wd_o            <= inst_i[15:11];
                                    link_addr_o             <= pc_plus_8;
                                    branch_flag_o           <= `Branch;
                                    branch_target_address_o <= reg1_o;
                                    next_inst_in_delayslot_o<= `InDelaySlot;
                                end
                                default begin
                                end
                            endcase
                        end
                        default begin
                        end                            
                    endcase     //case op2
                end
                `EXE_ORI: begin                     //ori指令  
                    //ori指令需要写入结果
                    wreg_o          <= `WriteEnable;
                    //运算子类型为逻辑或
                    aluop_o         <= `EXE_OR_OP;
                    //运算类型是逻辑运算
                    alusel_o        <= `EXE_RES_LOGIC;
                    //通过Regfile的读端口1读取寄存器
                    reg1_read_o     <= 1'b1;
                    //用不到读端口2
                    reg2_read_o     <= 1'b0;
                    //指令执行需要的立即数
                    imm             <= {16'h0, inst_i[15:0]};
                    //指令执行写入目的寄存器地址
                    wd_o            <= inst_i[20:16];
                    //ori指令是有效指令
                    instvalid       <= `InstValid;
                end
                `EXE_ANDI: begin                    //andi指令
                    wreg_o          <= `WriteEnable;
                    aluop_o         <= `EXE_AND_OP;
                    alusel_o        <= `EXE_RES_LOGIC;
                    reg1_read_o     <= 1'b1;
                    reg2_read_o     <= 1'b0;
                    imm             <= {16'h0, inst_i[15:0]};
                    wd_o            <= inst_i[20:16];
                    instvalid       <= `InstValid;
                end
                `EXE_XORI: begin                    //xori指令
                    wreg_o          <= `WriteEnable;
                    aluop_o         <= `EXE_XOR_OP;
                    alusel_o        <= `EXE_RES_LOGIC;
                    reg1_read_o     <= 1'b1;
                    reg2_read_o     <= 1'b0;
                    imm             <= {16'h0, inst_i[15:0]};
                    wd_o            <= inst_i[20:16];
                    instvalid       <= `InstValid;
                end
                `EXE_LUI: begin                    //lui指令
                    wreg_o          <= `WriteEnable;
                    aluop_o         <= `EXE_OR_OP;
                    alusel_o        <= `EXE_RES_LOGIC;
                    reg1_read_o     <= 1'b1;
                    reg2_read_o     <= 1'b0;
                    imm             <= {inst_i[15:0], 16'h0};
                    wd_o            <= inst_i[20:16];
                    instvalid       <= `InstValid;
                end
                `EXE_SLTI: begin                    // slti指令
                    wreg_o          <= `WriteEnable;
                    aluop_o         <= `EXE_SLT_OP;
                    alusel_o        <= `EXE_RES_ARITHMETIC;
                    reg1_read_o     <= 1'b1;
                    reg2_read_o     <= 1'b0;
                    imm             <= {{16{inst_i[15]}}, inst_i[15:0]};
                    wd_o            <= inst_i[20:16];
                    instvalid       <= `InstValid;
                end
                `EXE_SLTIU: begin                   // sltiu指令
                    wreg_o          <= `WriteEnable;
                    aluop_o         <= `EXE_SLTU_OP;
                    alusel_o        <= `EXE_RES_ARITHMETIC;
                    reg1_read_o     <= 1'b1;
                    reg2_read_o     <= 1'b0;
                    imm             <= {{16{inst_i[15]}}, inst_i[15:0]};
                    wd_o            <= inst_i[20:16];
                    instvalid       <= `InstValid;
                end
                `EXE_ADDI: begin                    // addi指令
                    wreg_o          <= `WriteEnable;
                    aluop_o         <= `EXE_ADDI_OP;
                    alusel_o        <= `EXE_RES_ARITHMETIC;
                    reg1_read_o     <= 1'b1;
                    reg2_read_o     <= 1'b0;
                    imm             <= {{16{inst_i[15]}}, inst_i[15:0]};
                    wd_o            <= inst_i[20:16];
                    instvalid       <= `InstValid;
                end
                `EXE_ADDIU: begin                    // addiu指令
                    wreg_o          <= `WriteEnable;
                    aluop_o         <= `EXE_ADDIU_OP;
                    alusel_o        <= `EXE_RES_ARITHMETIC;
                    reg1_read_o     <= 1'b1;
                    reg2_read_o     <= 1'b0;
                    imm             <= {{16{inst_i[15]}}, inst_i[15:0]};
                    wd_o            <= inst_i[20:16];
                    instvalid       <= `InstValid;
                end

                `EXE_J:	begin
                    wreg_o          <= `WriteDisable;
                    aluop_o         <= `EXE_J_OP;
                    alusel_o        <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o     <= 1'b0;
                    reg2_read_o     <= 1'b0;
                    link_addr_o     <= `ZeroWord;
                    branch_target_address_o     <= {pc_plus_4[31:28], inst_i[25:0], 2'b00};
                    branch_flag_o   <= `Branch;
                    next_inst_in_delayslot_o    <= `InDelaySlot;		  	
                    instvalid       <= `InstValid;	
				end
				`EXE_JAL: begin
                    wreg_o              <= `WriteEnable;
                    aluop_o             <= `EXE_JAL_OP;
                    alusel_o            <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o         <= 1'b0;
                    reg2_read_o         <= 1'b0;
                    wd_o                <= 5'b11111;	
                    link_addr_o         <= pc_plus_8 ;
                    branch_target_address_o     <= {pc_plus_4[31:28], inst_i[25:0], 2'b00};
                    branch_flag_o       <= `Branch;
                    next_inst_in_delayslot_o    <= `InDelaySlot;		  	
                    instvalid           <= `InstValid;	
				end
				`EXE_BEQ:			begin
                    wreg_o              <= `WriteDisable;
                    aluop_o             <= `EXE_BEQ_OP;
                    alusel_o            <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o         <= 1'b1;
                    reg2_read_o         <= 1'b1;
                    instvalid           <= `InstValid;	
                    if(reg1_o == reg2_o) begin
                        branch_target_address_o     <= pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o               <= `Branch;
                        next_inst_in_delayslot_o    <= `InDelaySlot;		  	
                    end
				end
				`EXE_BGTZ:			begin
                    wreg_o              <= `WriteDisable;
                    aluop_o             <= `EXE_BGTZ_OP;
                    alusel_o            <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o         <= 1'b1;
                    reg2_read_o         <= 1'b0;
                    instvalid           <= `InstValid;	
                    if((reg1_o[31] == 1'b0) && (reg1_o != `ZeroWord)) begin
                        branch_target_address_o     <= pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o               <= `Branch;
                        next_inst_in_delayslot_o    <= `InDelaySlot;		  	
                    end
				end
				`EXE_BLEZ:			begin
                    wreg_o              <= `WriteDisable;
                    aluop_o             <= `EXE_BLEZ_OP;
                    alusel_o            <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o         <= 1'b1;
                    reg2_read_o         <= 1'b0;
                    instvalid           <= `InstValid;	
                    if((reg1_o[31] == 1'b1) || (reg1_o == `ZeroWord)) begin
                        branch_target_address_o     <= pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o               <= `Branch;
                        next_inst_in_delayslot_o    <= `InDelaySlot;		  	
                    end
				end
				`EXE_BNE:			begin
                    wreg_o              <= `WriteDisable;
                    aluop_o             <= `EXE_BLEZ_OP;
                    alusel_o            <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o         <= 1'b1;
                    reg2_read_o         <= 1'b1;
                    instvalid           <= `InstValid;	
                    if(reg1_o != reg2_o) begin
                        branch_target_address_o     <= pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o               <= `Branch;
                        next_inst_in_delayslot_o    <= `InDelaySlot;		  	
                    end
				end

                `EXE_LB:			begin
                    wreg_o              <= `WriteEnable;
                    aluop_o             <= `EXE_LB_OP;
                    alusel_o            <= `EXE_RES_LOAD_STORE;
                    reg1_read_o         <= 1'b1;
                    reg2_read_o         <= 1'b0;	  	
                    wd_o                <= inst_i[20:16];
                    instvalid           <= `InstValid;	
				end
				`EXE_LW:			begin
                    wreg_o              <= `WriteEnable;
                    aluop_o             <= `EXE_LW_OP;
                    alusel_o            <= `EXE_RES_LOAD_STORE;
                    reg1_read_o         <= 1'b1;
                    reg2_read_o         <= 1'b0;	  	
                    wd_o                <= inst_i[20:16];
                    instvalid           <= `InstValid;	
				end
				`EXE_SB:			begin
                    wreg_o              <= `WriteDisable;
                    aluop_o             <= `EXE_SB_OP;
                    reg1_read_o         <= 1'b1;
                    reg2_read_o         <= 1'b1;
                    instvalid           <= `InstValid;	
                    alusel_o            <= `EXE_RES_LOAD_STORE; 
				end
				`EXE_SW:			begin
                    wreg_o              <= `WriteDisable;
                    aluop_o             <= `EXE_SW_OP;
                    reg1_read_o         <= 1'b1;
                    reg2_read_o         <= 1'b1;
                    instvalid           <= `InstValid;	
                    alusel_o            <= `EXE_RES_LOAD_STORE; 
				end

                `EXE_REGIMM_INST:		begin
					case (op4)
						`EXE_BGEZ:	begin
                            wreg_o      <= `WriteDisable;
                            aluop_o     <= `EXE_BGEZ_OP;
                            alusel_o    <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            instvalid   <= `InstValid;	
                            if(reg1_o[31] == 1'b0) begin
                                branch_target_address_o     <= pc_plus_4 + imm_sll2_signedext;
                                branch_flag_o               <= `Branch;
                                next_inst_in_delayslot_o    <= `InDelaySlot;		  	
                            end
						end
						`EXE_BLTZ:		begin
						    wreg_o      <= `WriteDisable;
                            aluop_o     <= `EXE_BGEZAL_OP;
                            alusel_o    <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
		  				    instvalid <= `InstValid;	
                            if(reg1_o[31] == 1'b1) begin
                                branch_target_address_o     <= pc_plus_4 + imm_sll2_signedext;
                                branch_flag_o               <= `Branch;
                                next_inst_in_delayslot_o    <= `InDelaySlot;		  	
                            end
						end
						default:	begin
						end
					endcase
				end	

                `EXE_SPECIAL2_INST:		begin
					case ( op3 )
						`EXE_MUL:		begin
							wreg_o <= `WriteEnable;
                            aluop_o <= `EXE_MUL_OP;
		  				    alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= 1'b1;	
                            reg2_read_o <= 1'b1;	
		  				    instvalid <= `InstValid;	  			
						end
						default:	begin
						end
					endcase      //EXE_SPECIAL_INST2 case
				end
                default : begin
                    
                end
                    
            endcase     //case op
            
            if (inst_i[31:21] == 11'b00000000000) begin
                if (op3 == `EXE_SLL) begin                  //sll指令 
                    wreg_o          <= `WriteEnable;
                    aluop_o         <= `EXE_SLL_OP;
                    alusel_o        <= `EXE_RES_SHIFT;
                    reg1_read_o     <= 1'b0;
                    reg2_read_o     <= 1'b1;
                    imm[4:0]        <= inst_i[10:6];
                    wd_o            <= inst_i[15:11];
                    instvalid       <= `InstValid;
                end else if (op3 == `EXE_SRL) begin          //srl指令 
                    wreg_o          <= `WriteEnable;
                    aluop_o         <= `EXE_SRL_OP;
                    alusel_o        <= `EXE_RES_SHIFT;
                    reg1_read_o     <= 1'b0;
                    reg2_read_o     <= 1'b1;
                    imm[4:0]        <= inst_i[10:6];
                    wd_o            <= inst_i[15:11];
                    instvalid       <= `InstValid;
                end else if (op3 == `EXE_SRA) begin          //sra指令 
                    wreg_o          <= `WriteEnable;
                    aluop_o         <= `EXE_SRA_OP;
                    alusel_o        <= `EXE_RES_SHIFT;
                    reg1_read_o     <= 1'b0;
                    reg2_read_o     <= 1'b1;
                    imm[4:0]        <= inst_i[10:6];
                    wd_o            <= inst_i[15:11];
                    instvalid       <= `InstValid;
                end
            end         //if (inst_i[31:21] == 11'b00000000000)
        end         //if
    end         //always


    /*Part.2 确定进行运算的源操作数1*/
        always @ (*) begin
            stallreq_for_reg1_loadrelate        <= `NoStop;
            if (rst == `RstEnable) begin
                reg1_o              <= `ZeroWord;           
            end else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg1_addr_o 
			&& reg1_o == 1'b1 && ex_last_laddr_i == ex_last_saddr_i) begin
                reg1_o              <= ex_last_sdata_i;
            //发生load冒险需要暂停流水线
            end else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg1_addr_o && reg1_read_o == 1'b1) begin
                stallreq_for_reg1_loadrelate    <= `Stop;
            end else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg1_addr_o)) begin
                reg1_o              <= ex_wdata_i;      //如果Regfile模块读端口1要读的寄存器就是执行阶段要写的目的寄存器，直接输出执行阶段的结果
            end else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg1_addr_o)) begin
                reg1_o              <= mem_wdata_i;     //如果Regfile模块读端口1要读的寄存器就是访存阶段要写的目的寄存器，直接输出执行阶段的结果
            end else if(reg1_read_o == 1'b1) begin
                reg1_o              <= reg1_data_i;     //Regfile读端口2的输出
            end else if(reg1_read_o == 1'b0) begin
                reg1_o              <= imm;             //立即数
            end else begin
                reg1_o              <= `ZeroWord;
            end
        end
    
    /*Part.3 确定进行运算的源操作数2*/
        always @ (*) begin
            stallreq_for_reg2_loadrelate        <=`NoStop;
            if (rst == `RstEnable) begin
                reg2_o              <= `ZeroWord;           
            end else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg2_addr_o 
			&& reg2_o == 1'b1 && ex_last_laddr_i == ex_last_saddr_i) begin
                reg2_o              <= ex_last_sdata_i;
            end else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg2_addr_o && reg2_read_o == 1'b1) begin
                stallreq_for_reg2_loadrelate    <= `Stop;
            end else if((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg2_addr_o)) begin
                reg2_o              <= ex_wdata_i;      //如果Regfile模块读端口1要读的寄存器就是执行阶段要写的目的寄存器，直接输出执行阶段的结果
            end else if((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg2_addr_o)) begin
                reg2_o              <= mem_wdata_i;     //如果Regfile模块读端口1要读的寄存器就是访存阶段要写的目的寄存器，直接输出执行阶段的结果
            end else if(reg2_read_o == 1'b1) begin
                reg2_o              <= reg2_data_i;     //Regfile读端口2的输出
            end else if(reg2_read_o == 1'b0) begin
                reg2_o              <= imm;             //立即数
            end else begin
                reg2_o              <= `ZeroWord;
            end
        end

    // 输出is_in_delayslot_o表示当前译码阶段指令是否是延迟槽指令
    always @(*) begin
        if (rst == `RstEnable) begin
            is_in_delayslot_o       <= `NotInDelaySlot;
        end else begin
            is_in_delayslot_o       <= is_in_delayslot_i;
        end
            
    end


endmodule