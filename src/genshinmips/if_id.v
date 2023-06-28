`include "define.v"
/*
IF/ID模块：暂时保存取址阶段取得的指令及其对应地址，
           并在下一个时钟传递到译码阶段
*/
module if_id(
    input wire                  clk,
    input wire                  rst,
    input wire[5:0]             stall,    

    //来自取址阶段的信号，InstAddrBus表示指令宽度(32)
    input wire [`InstAddrBus]   if_pc,
    input wire [`InstBus]       if_inst,

    //对应译码阶段的信号
    output reg [`InstAddrBus]   id_pc,
    output reg [`InstBus]       id_inst
);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            id_pc               <= `ZeroWord;       //复位时pc取0
            id_inst             <= `ZeroWord;       //复位时指令取0，即空指令
        end else if (stall[1] == `Stop && stall[2] == `NoStop) begin //取值暂停，译码继续
            id_pc               <= `ZeroWord;           
            id_inst             <= `ZeroWord;
        end else if (stall[1] == `NoStop) begin
            id_pc               <= if_pc;           //向下传递取值阶段的值
            id_inst             <= if_inst;
        end
    end
endmodule