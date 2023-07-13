`include "define.v"

/*
EX模块：对ID/EX模块传来的数据进行运算
*/

module ex(
    input wire                  rst,
    input wire [`InstAddrBus]   debug_pc, 


    //ID阶段送到EX阶段的信息
    input wire [`AluOpBus]      aluop_i,    //执行阶段要进行的运算类型

    input wire [`RegBus]        reg1_i,     //参与运算的源操作数1
    input wire [`RegBus]        reg2_i,     //参与运算的源操作数2
    input wire [`RegAddrBus]    waddr_i,       //指令执行要写入的寄存器地址
    input wire                  we_i,     //写入使能

    //EX阶段转移指令要保存的返回地址
    input  wire [`RegBus]       link_addr_i,

    //当前指令
    input  wire [`RegBus]       inst_i,

    //执行结果，送往WB阶段
    output reg [`RegAddrBus]    waddr_o,       //写入寄存器地址
    output reg                  we_o,     //执行阶段写入使能
    output reg [`RegBus]        wdata_o,    //写入寄存器的值


    //访存指令输出接口（访存）
    output reg  [`AluOpBus]     aluop_o,    //存储类型，同时送往id判断load相关
    output reg  [`RegBus]       mem_addr_o, //存储地址
    output reg  [`RegBus]       mem_data_o      //存储数据
);

    //执行阶段
    always @(*) begin
        if(rst == `RstEnable) begin
            wdata_o = `ZeroWord;
            waddr_o = `NOPRegAddr;
            we_o = `WriteDisable;
        end else begin
            wdata_o = `ZeroWord;
            waddr_o = waddr_i;
            we_o = we_i;
            case(aluop_i)     
                `EXE_AND_OP: begin
                    wdata_o = reg1_i & reg2_i;
                end      
                `EXE_OR_OP: begin
                    wdata_o = reg1_i | reg2_i;
                end    
                `EXE_XOR_OP: begin
                    wdata_o = reg1_i ^ reg2_i;
                end     
                `EXE_NOR_OP: begin
                    wdata_o = ~(reg1_i | reg2_i);
                end

                `EXE_SLL_OP: begin
                    wdata_o = reg2_i << reg1_i[4:0];
                end      
                `EXE_SRL_OP: begin
                    wdata_o = reg2_i >> reg1_i[4:0];
                end      
                `EXE_SRA_OP: begin
                    wdata_o = ($signed(reg2_i)) >>> reg1_i[4:0];
                end      

                `EXE_SLT_OP: begin
                    wdata_o = ($signed(reg1_i) < $signed(reg2_i)) ? 1 : 0;
                end     
                `EXE_SLTU_OP: begin
                    wdata_o = (reg1_i < reg2_i) ? 1 : 0;
                end
                `EXE_ADD_OP: begin
                    wdata_o = reg1_i + reg2_i;
                end
                `EXE_SUB_OP: begin
                    wdata_o = reg1_i + (~reg2_i) + 1;
                end      
                `EXE_MUL_OP: begin
                    wdata_o = reg1_i * reg2_i;   //无符号乘法代替有符号乘法
                end      
                
                `EXE_JAL_OP: begin
                    wdata_o = link_addr_i;
                end
            endcase
        end
    end

    //送往mem阶段的信息
    
    wire[31:0]  imm_s   =   {{16{inst_i[15]}},inst_i[15:0]};

    always @(*) begin
        if(rst == `RstEnable) begin
            aluop_o = `EXE_NOP_OP;
            mem_addr_o = `ZeroWord;
            mem_data_o = `ZeroWord;
        end else begin
            case(aluop_i)
                `EXE_LB_OP: begin
                    aluop_o = `EXE_LB_OP;
                    mem_addr_o = reg1_i + imm_s;
                    mem_data_o = `ZeroWord;
                end       
                `EXE_LW_OP: begin
                    aluop_o = `EXE_LW_OP;
                    mem_addr_o = reg1_i + imm_s;
                    mem_data_o = `ZeroWord;
                end       
                `EXE_SB_OP: begin
                    aluop_o = `EXE_SB_OP;
                    mem_addr_o = reg1_i + imm_s;
                    mem_data_o = reg2_i;
                end       
                `EXE_SW_OP: begin
                    aluop_o = `EXE_SW_OP;
                    mem_addr_o = reg1_i + imm_s;
                    mem_data_o = reg2_i;
                end       
                default: begin
                    aluop_o = `EXE_NOP_OP;
                    mem_addr_o = `ZeroWord;
                    mem_data_o = `ZeroWord;
                end
            endcase
        end
    end

endmodule