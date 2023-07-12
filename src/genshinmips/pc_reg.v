`include "define.v"
/**
PC模块：给出指令地址
*/
module pc_reg(
    input wire                      clk,
    input wire                      rst,
    
    //来自控制模块
    input wire [5:0]                stall, //中断请求
    
    //来自译码阶段（ID）
    input wire                      branch_flag_i,              //分支flag
    input wire [`RegBus]            branch_target_address_i,    //分支地址

    output reg [`InstAddrBus]       pc, //要读取的指令地址
    output reg                      ce  //指令存储器使能信号
);

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            ce                      <= `ChipDisable;         //复位时指令存储器禁用
        end else begin
            ce                      <= `ChipEnable;          //复位完成后指令存储器使能
        end
    end

    always @(posedge clk) begin
        if(ce == `ChipDisable) begin
            pc <= `PC_BEGIN_ADDR;
        end else if(stall[0] == `NoStop) begin
            if(branch_flag_i == `Branch) begin
                pc <= branch_target_address_i;
            end else begin
                pc <= pc + 4'h4;
            end
        end
        //流水线暂停，保持原有状态
    end

endmodule