`include "define.v"

/*
MEM/WB模块：将访存阶段运算结果在下一个时钟传递到回写阶段
*/

module mem_wb (
    input  wire                rst,
    input  wire                clk,
    input  wire [`InstAddrBus] debug_pc_i,
    output reg  [`InstAddrBus] debug_pc_o,


    //来自访存阶段的信息
    input wire [`RegAddrBus] mem_waddr,  //访存阶段的指令访存后写入寄存器地址
    input wire               mem_we,     //访存阶段的指令访存后写入使能
    input wire [    `RegBus] mem_wdata,  //访存阶段的指令访存后写入值

    input wire [5:0] stall,

    //送到回写阶段的信息
    output reg [`RegAddrBus] wb_waddr,  //回写阶段的指令写入寄存器地址
    output reg               wb_we,     //回写阶段的指令写入使能
    output reg [    `RegBus] wb_wdata   //回写阶段的指令写入值
);

  always @(posedge clk) begin
    if (rst == `RstEnable) begin
      wb_waddr   <= `NOPRegAddr;
      wb_we      <= `WriteDisable;
      wb_wdata   <= `ZeroWord;
      debug_pc_o <= `ZeroWord;
    end 
    // else if (stall[4] == `Stop && stall[5] == `NoStop) begin
    //   wb_waddr   <= `NOPRegAddr;
    //   wb_we      <= `WriteDisable;
    //   wb_wdata   <= `ZeroWord;
    //   debug_pc_o <= `ZeroWord;
    // end
     else if (stall[4] == `NoStop) begin
      wb_waddr   <= mem_waddr;
      wb_we      <= mem_we;
      wb_wdata   <= mem_wdata;
      debug_pc_o <= debug_pc_i;
    end
  end

endmodule
