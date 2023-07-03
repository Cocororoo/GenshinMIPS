`include "define.v"

/*
EX/MEM模块：将执行阶段取得的运算结果在下一个时钟传递到访存阶段
*/

module ex_mem(
    input wire                  rst,
    input wire                  clk,

    //来自执行阶段的信息
    input wire [`RegAddrBus]    ex_wd,      //执行阶段的指令执行后写入寄存器地址
    input wire                  ex_wreg,    //执行阶段的指令执行后写入使能
    input wire [`RegBus]        ex_wdata,   //执行阶段的指令执行后写入值

    //访存指令输入接口
    input wire [`AluOpBus]      ex_aluop,
    input wire [`RegBus]        ex_mem_addr,
    input wire [`RegBus]        ex_reg2,

    input wire [5:0]            stall,

    //送到访存阶段的信息
    output reg [`RegAddrBus]    mem_wd,      //访存阶段的指令写入寄存器地址
    output reg                  mem_wreg,    //访存阶段的指令写入使能
    output reg [`RegBus]        mem_wdata,   //访存阶段的指令写入值

    //访存指令输出接口
    output reg [`AluOpBus]      mem_aluop,
    output reg [`RegBus]        mem_mem_addr,
    output reg [`RegBus]        mem_reg2,

    //前推到ID阶段的数据
    output  reg [`DataBus]      id_last_sdata_o,
    output  reg [`DataAddrBus]  id_last_saddr_o
);

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            mem_wd              <= `NOPRegAddr;
            mem_wreg            <= `WriteDisable;
            mem_wdata           <= `ZeroWord;

            mem_aluop           <= `EXE_NOP_OP;
            mem_mem_addr        <= `ZeroWord;
            mem_reg2            <= `ZeroWord;

            id_last_saddr_o     <= `ZeroWord;
            id_last_sdata_o     <= `ZeroWord;
        end 
        // else if (stall[3] == `Stop && stall[4] == `NoStop) begin
        //     mem_wd              <= `NOPRegAddr;
        //     mem_wreg            <= `WriteDisable;
        //     mem_wdata           <= `ZeroWord;
        // end else if (stall[3] == `NoStop)
         begin
            mem_wd              <= ex_wd;
            mem_wreg            <= ex_wreg;
            mem_wdata           <= ex_wdata;

            mem_aluop           <= ex_aluop;
            mem_mem_addr        <= ex_mem_addr;
            mem_reg2            <= ex_reg2;

            case(ex_aluop)
                `EXE_SB_OP: begin
                    id_last_saddr_o <= ex_mem_addr;
                    case(ex_mem_addr[1:0])
                    2'b00: begin
                        id_last_sdata_o <= {24'h000000,ex_reg2[7:0]};
                    end 
                    2'b01: begin
                        id_last_sdata_o <= {16'h0000,ex_reg2[7:0],8'h00};
                    end
                    2'b10: begin
                        id_last_sdata_o <= {8'h00,ex_reg2[7:0],16'h0000};
                    end
                    2'b11: begin
                        id_last_sdata_o <= {ex_reg2[7:0],24'h000000};
                    end
                    default : begin
                        id_last_sdata_o <= id_last_sdata_o;
                    end
                endcase
                end
                `EXE_SW_OP: begin
                    id_last_saddr_o <= ex_mem_addr;
                    id_last_sdata_o <= ex_reg2;
                end
                default: begin
                    id_last_saddr_o <= id_last_saddr_o;
                    id_last_sdata_o <= id_last_sdata_o;
                end
            endcase

        end
    end

endmodule