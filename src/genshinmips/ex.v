`include "define.v"

/*
EX模块：对ID/EX模块传来的数据进行运算
*/

module ex(
    input wire                  rst,

    //译码阶段送到执行阶段的信息
    input wire [`AluOpBus]      aluop_i,    //执行阶段要进行的运算类型
    input wire [`AluSelBus]     alusel_i,   //执行阶段要进行的运算子类型
    input wire [`RegBus]        reg1_i,     //参与运算的源操作数1
    input wire [`RegBus]        reg2_i,     //参与运算的源操作数2
    input wire [`RegAddrBus]    wd_i,       //指令执行要写入的寄存器地址
    input wire                  wreg_i,     //写入使能

    //执行阶段转移指令要保存的返回地址
    input  wire [`RegBus]       link_address_i,
    //当前执行阶段指令是否位于延迟槽
    input  wire                 is_in_delayslot_i,

    //当前指令
    input  wire [`RegBus]       inst_i,

    //执行结果，送往回写阶段
    output reg [`RegAddrBus]    wd_o,       //写入寄存器地址
    output reg                  wreg_o,     //执行阶段写入使能
    output reg [`RegBus]        wdata_o,    //写入寄存器的值

    //中断请求
    output wire                 stallreq,

    //访存指令输出接口（访存）
    output wire [`AluOpBus]     aluop_o,    //存储类型，同时送往id判断load相关
    output wire [`RegBus]       mem_addr_o, //存储地址
    output wire [`RegBus]       reg2_o      //存储数据

    // //送往mem阶段的信息（访存相关）
    // output  reg [3:0]    mem_op,         //存储类型,同时要送往id阶段以判断load相关
    // output  reg [31:0]   mem_addr_o,     //存储地址
    // output  reg [31:0]   mem_data_o     //存储数据
);

    reg [`RegBus]               logicout;       //保存逻辑运算的结果
    reg [`RegBus]               shiftres;       //保存移位运算的结果
    reg [`RegBus]               arithmeticres;  //保存算术运算的结果
    


    wire                        ov_sum;         //溢出情况
    wire                        reg1_eq_reg2;   //两操作数是否相等
    wire                        reg1_lt_reg2;   //第一个操作数是否小于第二个
    wire [`RegBus]              reg2_i_mux;     //保存第二个操作数补码
    wire [`RegBus]              reg1_i_not;     //保存第一个操作数取反
    wire [`RegBus]              result_sum;     //保存加法结果
    wire [`RegBus]              opdata1_mult;   //被乘数
    wire [`RegBus]              opdata2_mult;   //乘数
    wire [`DoubleRegBus]        hilo_temp;      //临时乘法结果
    reg  [`DoubleRegBus]        mulres;         //乘法结果（64位）

    assign                      aluop_o = aluop_i;
    assign                      mem_addr_o = reg1_i + {{16{inst_i[15]}}, inst_i[15:0]};
    assign                      reg2_o = reg2_i;
    
    assign                      reg2_i_mux = ((aluop_i == `EXE_SUB_OP) ||
                                            (aluop_i == `EXE_SUBU_OP) ||
                                            (aluop_i == `EXE_SLT_OP)) ?
                                            (~reg2_i) + 1 : reg2_i;

    assign                      result_sum = reg1_i + reg2_i_mux;

 	assign                      ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) ||
									    ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));  
									
	assign                      reg1_lt_reg2 = ((aluop_i == `EXE_SLT_OP)) ?
												 ((reg1_i[31] && !reg2_i[31]) || 
												 (!reg1_i[31] && !reg2_i[31] && result_sum[31])||
			                   (reg1_i[31] && reg2_i[31] && result_sum[31]))
			                   :	(reg1_i < reg2_i);
  
    assign                      reg1_i_not = ~reg1_i;

    /*依据不同算术运算类型，给arithmeticres赋值*/
    always @(*) begin
        if (rst == `RstEnable) begin
            arithmeticres           <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_SLT_OP, `EXE_SLTU_OP: begin
                    arithmeticres   <= reg1_lt_reg2;
                end
                `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP: begin
                    arithmeticres   <= result_sum;
                end
                `EXE_SUB_OP, `EXE_SUBU_OP: begin
                    arithmeticres   <= result_sum;
                end
                default begin
                    arithmeticres   <= `ZeroWord;
                end    
            endcase
        end            
    end

    /*乘法运算*/
    assign      opdata1_mult = ((aluop_i == `EXE_MUL_OP) && (reg1_i[31] == 1'b1)
                                ? (~reg1_i + 1) : reg1_i);
    assign      opdata2_mult = ((aluop_i == `EXE_MUL_OP) && (reg2_i[31] == 1'b1)
                                ? (~reg2_i + 1) : reg2_i);
    assign      hilo_temp = opdata1_mult * opdata2_mult;

    always @(*) begin
        if (rst == `RstEnable) begin
            mulres              <= {`ZeroWord, `ZeroWord};
        end else if(aluop_i == `EXE_MUL_OP) begin
            if (reg1_i[31] ^ reg2_i[31] == 1'b1) begin
                mulres          <= ~hilo_temp + 1;
            end else
                mulres          <= hilo_temp;
        end else
            mulres              <= hilo_temp;
    end

    /*Part.1 依据aluop_i指示的运算子类型进行逻辑运算*/
    always @ (*) begin
        if (rst == `RstEnable) begin
            logicout            <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_OR_OP: begin           //逻辑或
                    logicout    <= reg1_i | reg2_i;
                end
                `EXE_AND_OP: begin          //逻辑与
                    logicout    <= reg1_i & reg2_i;
                end
                `EXE_NOR_OP: begin          //逻辑或非
                    logicout    <= ~(reg1_i | reg2_i);
                end
                `EXE_XOR_OP: begin          //逻辑异或
                    logicout    <= reg1_i ^ reg2_i;
                end
                default: begin
                    logicout    <= `ZeroWord;
                end
            endcase
        end     //if
    end     //always

    /*Part.2 依据aluop_i指示的运算子类型进行移位运算*/
    always @ (*) begin
        if (rst == `RstEnable) begin
            shiftres            <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_SLL_OP: begin          //逻辑左移
                    shiftres    <= reg2_i << reg1_i[4:0];
                end
                `EXE_SRL_OP: begin          //逻辑右移
                    shiftres    <= reg2_i >> reg1_i[4:0];
                end
                `EXE_SRA_OP: begin          //算术右移
                    shiftres    <= ( { {31{reg2_i}}, 1'b0 } << (~reg1_i[4:0]) ) | ( reg2_i >> reg1_i[4:0] );
                end
                default: begin
                    shiftres    <= `ZeroWord;
                end
            endcase
        end     //if
    end     //always

    /*Part.3 依据alusel_i指示的运算类型，选择一个运算结果作为最终结果*/
    always @ (*) begin
        wd_o                    <= wd_i;        //要写入的寄存器地址
        
        if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || 
	      (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1)) begin
	 	    wreg_o <= `WriteDisable;
	    end else 
            wreg_o                  <= wreg_i;      //写入使能
        case (alusel_i)
            `EXE_RES_LOGIC: begin
                wdata_o         <= logicout;    //选择wdata_o存放逻辑运算结果
            end
            `EXE_RES_SHIFT: begin
                wdata_o         <= shiftres;    //选择wdata_o存放移位运算结果
            end
            `EXE_RES_ARITHMETIC: begin
                wdata_o         <= arithmeticres;
            end
            `EXE_RES_MUL: begin
                wdata_o         <= mulres[31:0];
            end
            `EXE_RES_JUMP_BRANCH: begin
                wdata_o         <= link_address_i;
            end
            default: begin
                wdata_o         <= `ZeroWord;
            end
        endcase
    end

endmodule