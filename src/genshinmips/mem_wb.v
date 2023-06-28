`include "define.v"

/*
MEM/WB模块：将访存阶段运算结果在下一个时钟传递到回写阶段
*/

module mem_wb(
    input wire                  rst,
    input wire                  clk,

    //来自访存阶段的信息
    input wire [`RegAddrBus]    mem_wd,      //访存阶段的指令访存后写入寄存器地址
    input wire                  mem_wreg,    //访存阶段的指令访存后写入使能
    input wire [`RegBus]        mem_wdata,   //访存阶段的指令访存后写入值

    input wire [5:0]            stall,

    //送到回写阶段的信息
    output reg [`RegAddrBus]    wb_wd,      //回写阶段的指令写入寄存器地址
    output reg                  wb_wreg,    //回写阶段的指令写入使能
    output reg [`RegBus]        wb_wdata    //回写阶段的指令写入值
);

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            wb_wd               <= `NOPRegAddr;
            wb_wreg             <= `WriteDisable;
            wb_wdata            <= `ZeroWord;
        end else if (stall[4] == `Stop && stall[5] == `NoStop) begin
            wb_wd               <= `NOPRegAddr;
            wb_wreg             <= `WriteDisable;
            wb_wdata            <= `ZeroWord;
        end else if (stall[4] == `NoStop) begin
            wb_wd               <= mem_wd;
            wb_wreg             <= mem_wreg;
            wb_wdata            <= mem_wdata;
        end
    end

endmodule