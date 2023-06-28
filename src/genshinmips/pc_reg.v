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
    input wire                      branch_flag_i,
    input wire [`RegBus]            branch_target_address_i,

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

    always @ (posedge clk) begin
        if (ce == `ChipDisable) begin
            pc                      <= 32'h0000_0000;        //指令存储器禁用时，pc为0
        end else if (stall[0] == `NoStop) begin
            if (branch_flag_i == `Branch) begin
                pc                  <= branch_target_address_i;
            end else begin
                pc                      <= pc + 4'h4;            //指令存储器使能且未中断时，pc每周期+4，对应一条指令4个字节                
            end    
        end
    end

endmodule