`include "define.v"

/*
* id模块：对指令译码，得到最终运算的类型、子类型、源操作数1、源操作数2、要写入的目的寄存器地址等
*/

module id (
    input wire                rst,
    input wire [`InstAddrBus] id_pc_i,   //译码阶段指令对应地址
    input wire [    `InstBus] inst_i, //译码阶段的指令

    //输出到Regfile的信息
    output reg               reg1_re_o,     //Regfile第一个读寄存器端口的读使能
    output reg               reg2_re_o,     //Regfile第二个读寄存器端口的读使能
    output reg [`RegAddrBus] reg1_raddr_o,  //Regfile第一个读寄存器端口的地址
    output reg [`RegAddrBus] reg2_raddr_o,  //Regfile第二个读寄存器端口的地址

    //读取的Regfile值
    input wire [`RegBus] reg1_data_i,
    input wire [`RegBus] reg2_data_i,

    //送到EX阶段的信息
    output reg [`AluOpBus] aluop_o,  //译码阶段的指令要进行的运算子类型
    output reg [`RegBus] reg1_data_o,  //译码阶段的指令要进行的运算的源操作数1
    output reg [`RegBus] reg2_data_o,  //译码阶段的指令要进行的运算的源操作数2
    output reg [`RegAddrBus] waddr_o,  //译码阶段的指令要写入的目的地寄存器地址
    output reg we_o,  //译码阶段的指令是否有要写入的目的寄存器
    output wire [`RegBus] inst_o,  //将指令码输出

    //数据前推实现：处于EX阶段指令的运算结果
    input wire               ex_we_i,
    input wire [    `RegBus] ex_wdata_i,
    input wire [`RegAddrBus] ex_waddr_i,  //执行阶段写寄存器的地址

    //数据前推实现：处于MEM阶段的指令运算结果
    input wire               mem_we_i,
    input wire [    `RegBus] mem_wdata_i,
    input wire [`RegAddrBus] mem_waddr_i,

    //load冒险处理
    input wire [`DataAddrBus] ex_last_laddr_i,  //上一次加载地址
    input wire [`DataAddrBus] ex_last_saddr_i,  //上一次存储地址
    input wire [    `DataBus] ex_last_sdata_i,  //上一次存储数据

    //用于判断上一条指令是否会产生load相关
    input wire [`AluOpBus] ex_aluop_i,

    //分支跳转
    output reg           branch_flag_o,
    output reg [`RegBus] branch_target_address_o,
    output reg [`RegBus] link_addr_o,

    //中断请求
    output wire stallreq
);

  //要读的寄存器是否与上条指令存在load相关
  reg  stallreq_for_reg1_loadrelate;
  reg  stallreq_for_reg2_loadrelate;
  wire pre_inst_is_load;
  assign pre_inst_is_load = ((ex_aluop_i == `EXE_LB_OP) || 
                                (ex_aluop_i == `EXE_LW_OP)) ? 1'b1 : 1'b0;

  assign inst_o = inst_i;
  assign stallreq = stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;

    // 提取指令各个字段
    // R型指令
    wire[5:0] op            = inst_i[31:26];
    wire[4:0] rs            = inst_i[25:21];
    wire[4:0] rt            = inst_i[20:16];
    wire[4:0] rd            = inst_i[15:11];
    wire[4:0] shamt         = inst_i[10:6];
    wire[5:0] func          = inst_i[5:0];

    // I型指令
    wire[15:0] imm          = inst_i[15:0];

    // J型指令
    wire[25:0] inst_index   = inst_i[25:0];

    // 立即数扩展
    wire[31:0] imm_u = {{16{1'b0}}, imm};       // 无符号扩展
    wire[31:0] imm_s = {{16{imm[15]}}, imm};    // 有符号扩展

    // 跳转地址
    wire[31:0] next_pc;
    wire[31:0] jump_addr = {next_pc[31:28], inst_index, 2'b00};
    wire[31:0] branch_addr = next_pc + {imm_s[29:0], 2'b00};

    // 选择是有符号扩展还是无符号扩展
    reg[31:0]   imm_o;

    assign next_pc = id_pc_i + 4'h4;

    //译码
    always @(*) begin
        if(rst == `RstEnable) begin
            aluop_o = `EXE_NOP_OP;
            reg1_re_o = `ReadDisable;
            reg1_raddr_o = `NOPRegAddr;
            reg2_re_o = `ReadDisable;
            reg2_raddr_o = `NOPRegAddr;
            we_o = `WriteDisable;
            waddr_o = `NOPRegAddr;
            imm_o = `ZeroWord;
        end else begin 
            aluop_o = `EXE_NOP_OP;
            reg1_re_o = `ReadDisable;
            reg1_raddr_o = rs;
            reg2_re_o = `ReadDisable;
            reg2_raddr_o = rt;
            we_o = `WriteDisable;
            waddr_o = rd;
            imm_o = `ZeroWord;
        end
        case(op)
            `ADDIU_OP,
            `ADDI_OP: begin
                aluop_o = `EXE_ADD_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteEnable;
                waddr_o = rt;
                imm_o = imm_s;
            end        
            `SLTI_OP: begin
                aluop_o = `EXE_SLT_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteEnable;
                waddr_o = rt;
                imm_o = imm_s;
            end
            `SLTIU_OP: begin
                aluop_o = `EXE_SLTU_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteEnable;
                waddr_o = rt;
                imm_o = imm_s;
            end
            `MUL_OP: begin
                if(shamt == 5'b00000) begin
                    case(func)
                        `MUL_FUNC: begin
                            aluop_o = `EXE_MUL_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end
                        default :begin
                        end
                    endcase
                end else begin
                end
            end

            `ANDI_OP: begin
                aluop_o = `EXE_AND_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteEnable;
                waddr_o = rt;
                imm_o = imm_u;
            end       
            `LUI_OP: begin
                aluop_o = `EXE_OR_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteEnable;
                waddr_o = rt;
                imm_o = {imm, 16'h0000};
            end        
            `ORI_OP: begin
                aluop_o = `EXE_OR_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteEnable;
                waddr_o = rt;
                imm_o = imm_u;
            end         
            `XORI_OP: begin
                aluop_o = `EXE_XOR_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteEnable;
                waddr_o = rt;
                imm_o = imm_u;
            end

            `BEQ_OP: begin
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadEnable;
                we_o = `WriteDisable;
            end
            `BNE_OP: begin
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadEnable;
                we_o = `WriteDisable;
            end        
            `BGTZ_OP: begin
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteDisable;
            end
            `BLEZ_OP: begin 
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteDisable;
            end
            `J_OP: begin
                reg1_re_o = `ReadDisable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteDisable;
            end        
            `JAL_OP:begin
                aluop_o = `EXE_JAL_OP;
                reg1_re_o = `ReadDisable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteEnable;
                waddr_o = 5'b11111;
            end

            `LB_OP: begin
                aluop_o = `EXE_LB_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteEnable;
                waddr_o = rt;
                imm_o = imm_s;
            end         
            `LW_OP: begin
                aluop_o = `EXE_LW_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadDisable;
                we_o = `WriteEnable;
                waddr_o = rt;
                imm_o = imm_s;
            end         
            `SB_OP: begin
                aluop_o = `EXE_SB_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadEnable;
                we_o = `WriteDisable;
            end           
            `SW_OP: begin
                aluop_o = `EXE_SW_OP;
                reg1_re_o = `ReadEnable;
                reg2_re_o = `ReadEnable;
                we_o = `WriteDisable;
            end           

            `R_OP: begin
                if(shamt == 5'b00000) begin
                    case(func)
                        `ADDU_FUNC,
                        `ADD_FUNC: begin
                            aluop_o = `EXE_ADD_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end
                        `SUBU_FUNC,
                        `SUB_FUNC: begin
                            aluop_o = `EXE_SUB_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end
                        `SLT_FUNC: begin
                            aluop_o = `EXE_SLT_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end
                        `SLTU_FUNC: begin
                            aluop_o = `EXE_SLTU_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end

                        `AND_FUNC: begin
                            aluop_o = `EXE_AND_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end  
                        `OR_FUNC: begin
                            aluop_o = `EXE_OR_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end   
                        `XOR_FUNC: begin
                            aluop_o = `EXE_XOR_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end   
                        `NOR_FUNC: begin
                            aluop_o = `EXE_NOR_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end

                        `SLLV_FUNC: begin
                            aluop_o = `EXE_SLL_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end  
                        `SRAV_FUNC: begin
                            aluop_o = `EXE_SRA_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end
                        `SRLV_FUNC :begin
                            aluop_o = `EXE_SRL_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                        end 

                        `JR_FUNC: begin
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadDisable;
                            we_o = `WriteDisable;
                        end
                        `JALR_FUNC: begin
                            aluop_o = `EXE_JAL_OP;
                            reg1_re_o = `ReadEnable;
                            reg2_re_o = `ReadDisable;
                            we_o = `WriteEnable;
                        end
                        default : begin
                        end
                    endcase
                end else if(rs == 5'b00000) begin
                    case(func)
                        `SLL_FUNC: begin
                            aluop_o = `EXE_SLL_OP;
                            reg1_re_o = `ReadDisable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                            waddr_o = rd;
                            imm_o[4:0] = shamt;
                        end   
                        `SRL_FUNC: begin
                            aluop_o = `EXE_SRL_OP;
                            reg1_re_o = `ReadDisable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                            waddr_o = rd;
                            imm_o[4:0] = shamt;
                        end
                        `SRA_FUNC: begin
                            aluop_o = `EXE_SRA_OP;
                            reg1_re_o = `ReadDisable;
                            reg2_re_o = `ReadEnable;
                            we_o = `WriteEnable;
                            waddr_o = rd;
                            imm_o[4:0] = shamt;
                        end
                        default : begin
                        end
                    endcase
                end else begin
                end    
            end       

            `SPECIAL_OP: begin
                case(rt)
                    `BLTZ_RT,
                    `BGEZ_RT: begin
                        reg1_re_o = `ReadEnable;
                        reg2_re_o = `ReadDisable;
                        we_o = `WriteDisable;
                    end
                    `BLTZAL_RT,
                    `BGEZAL_RT: begin
                        aluop_o = `EXE_JAL_OP;
                        reg1_re_o = `ReadEnable;
                        reg2_re_o = `ReadDisable;
                        we_o = `WriteDisable;
                    end
                    default : begin
                    end
                endcase
            end       
            default : begin
            end
        endcase
    end


    //确定是否跳转及跳转地址
    always @(*) begin
        if(rst == `RstEnable) begin
            branch_flag_o = `NotBranch;
            branch_target_address_o = `ZeroWord;
            link_addr_o = `ZeroWord;
        end else begin
            branch_flag_o = `NotBranch;
            branch_target_address_o = `ZeroWord;
            link_addr_o = `ZeroWord;
        end
        case(op)
            `BEQ_OP: begin
                if(reg1_data_o == reg2_data_o) begin
                    branch_flag_o = `Branch;
                    branch_target_address_o = branch_addr;
                end else begin 
                end
            end
            `BNE_OP: begin
                if(reg1_data_o != reg2_data_o) begin
                    branch_flag_o = `Branch;
                    branch_target_address_o = branch_addr;
                end else begin
                end
            end        
            `BGTZ_OP: begin
                if(reg1_data_o[31] == 1'b0 && reg1_data_o != `ZeroWord) begin
                    branch_flag_o = `Branch;
                    branch_target_address_o = branch_addr;
                end else begin
                end
            end
            `BLEZ_OP: begin 
                if(reg1_data_o[31] == 1'b1 || reg1_data_o == `ZeroWord) begin
                    branch_flag_o = `Branch;
                    branch_target_address_o = branch_addr;
                end else begin
                end
            end
            `J_OP: begin
                branch_flag_o = `Branch;
                branch_target_address_o = jump_addr;
            end        
            `JAL_OP: begin
                branch_flag_o = `Branch;
                branch_target_address_o = jump_addr;
                link_addr_o = next_pc + 4'h4;
            end
            `R_OP: begin
                if(shamt == 5'b00000) begin
                    case(func) 
                        `JR_FUNC: begin
                            branch_flag_o = `Branch;
                            branch_target_address_o = reg1_data_o;
                        end
                        `JALR_FUNC: begin
                            branch_flag_o = `Branch;
                            branch_target_address_o = reg1_data_o;
                            link_addr_o = next_pc + 4'h4;
                        end
                    default:	begin
                        end
                    endcase
                end
            end
            `SPECIAL_OP: begin
                case(rt)
                    `BGEZ_RT: begin
                        if(reg1_data_o[31] == 1'b0) begin
                            branch_flag_o = `Branch;
                            branch_target_address_o = branch_addr;
                        end else begin
                        end
                    end
                    `BLTZ_RT: begin
                        if(reg1_data_o[31] == 1'b1) begin
                            branch_flag_o = `Branch;
                            branch_target_address_o = branch_addr;
                        end else begin
                        end
                    end
                    `BGEZAL_RT: begin
                        if(reg1_data_o[31] == 1'b0) begin
                            branch_flag_o = `Branch;
                            branch_target_address_o = branch_addr;
                            link_addr_o = next_pc + 4'h4;
                        end else begin
                        end
                    end
                    `BLTZAL_RT: begin
                        if(reg1_data_o[31] == 1'b1) begin
                            branch_flag_o = `Branch;
                            branch_target_address_o = branch_addr;
                            link_addr_o = next_pc + 4'h4;
                        end else begin
                        end
                    end
                    default : begin
                    end
                endcase
            end       
            default :begin
                branch_flag_o = `NotBranch;
                branch_target_address_o = `ZeroWord;
                link_addr_o = `ZeroWord;
            end
        endcase
    end


  /*Part.2 确定进行运算的源操作数1*/
  always @(*) begin
    stallreq_for_reg1_loadrelate = `NoStop;
    reg1_data_o                  = `ZeroWord;
    if (rst == `RstEnable) begin
      reg1_data_o = `ZeroWord;
    end else if(pre_inst_is_load == 1'b1 && ex_waddr_i == reg1_raddr_o 
			&& reg1_re_o == 1'b1 && ex_last_laddr_i == ex_last_saddr_i) begin
      reg1_data_o = ex_last_sdata_i;
      //发生load冒险需要暂停流水线
    end else if (pre_inst_is_load == 1'b1 && ex_waddr_i == reg1_raddr_o && reg1_re_o == 1'b1) begin
      stallreq_for_reg1_loadrelate = `Stop;
    end else if ((reg1_re_o == 1'b1) && (ex_we_i == 1'b1) && (ex_waddr_i == reg1_raddr_o)) begin
      reg1_data_o              = ex_wdata_i;      //如果Regfile模块读端口1要读的寄存器就是执行阶段要写的目的寄存器，直接输出执行阶段的结果
    end else if ((reg1_re_o == 1'b1) && (mem_we_i == 1'b1) && (mem_waddr_i == reg1_raddr_o)) begin
      reg1_data_o              = mem_wdata_i;     //如果Regfile模块读端口1要读的寄存器就是访存阶段要写的目的寄存器，直接输出执行阶段的结果
    end else if (reg1_re_o == 1'b1) begin
      reg1_data_o = reg1_data_i;  //Regfile读端口2的输出
    end else if (reg1_re_o == 1'b0) begin
      reg1_data_o = imm;  //立即数
    end else begin
      reg1_data_o = `ZeroWord;
    end
  end

  /*Part.3 确定进行运算的源操作数2*/
  always @(*) begin
    stallreq_for_reg2_loadrelate = `NoStop;
    reg2_data_o                  = `ZeroWord;
    if (rst == `RstEnable) begin
      reg2_data_o = `ZeroWord;
    end else if(pre_inst_is_load == 1'b1 && ex_waddr_i == reg2_raddr_o 
			&& reg2_re_o == 1'b1 && ex_last_laddr_i == ex_last_saddr_i) begin
      reg2_data_o = ex_last_sdata_i;
    end else if (pre_inst_is_load == 1'b1 && ex_waddr_i == reg2_raddr_o && reg2_re_o == 1'b1) begin
      stallreq_for_reg2_loadrelate = `Stop;
    end else if ((reg2_re_o == 1'b1) && (ex_we_i == 1'b1) && (ex_waddr_i == reg2_raddr_o)) begin
      reg2_data_o              = ex_wdata_i;      //如果Regfile模块读端口1要读的寄存器就是执行阶段要写的目的寄存器，直接输出执行阶段的结果
    end else if ((reg2_re_o == 1'b1) && (mem_we_i == 1'b1) && (mem_waddr_i == reg2_raddr_o)) begin
      reg2_data_o              = mem_wdata_i;     //如果Regfile模块读端口1要读的寄存器就是访存阶段要写的目的寄存器，直接输出执行阶段的结果
    end else if (reg2_re_o == 1'b1) begin
      reg2_data_o = reg2_data_i;  //Regfile读端口2的输出
    end else if (reg2_re_o == 1'b0) begin
      reg2_data_o = imm;  //立即数
    end else begin
      reg2_data_o = `ZeroWord;
    end
  end


endmodule
