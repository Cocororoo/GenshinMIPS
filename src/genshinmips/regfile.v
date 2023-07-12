`include "define.v"

/*
regfile模块：寄存器堆，可以同时读2个寄存器和写1个寄存器
*/

module regfile(
    input wire                      clk,
    input wire                      rst,
    input wire                  pc, 


    //写端口
    input wire                      we,         //写入使能
    input wire [`RegAddrBus]        waddr,      //要写入的寄存器地址
    input wire [`RegBus]            wdata,      //要写入的值

    //读端口1
    input wire                      re1,
    input wire [`RegAddrBus]        raddr1,
    output reg [`RegBus]            rdata1,

    //读端口2
    input wire                      re2,
    input wire [`RegAddrBus]        raddr2,
    output reg [`RegBus]            rdata2
);

    /*Part.1 定义32个32位寄存器*/
    reg [`RegBus]                   regs [0 : `RegNum - 1];

    /*Part.2 写端口*/
    always @(posedge clk) begin
        if (rst == `RstDisable) begin
            if ((we == `WriteEnable) && (waddr != `RegNumLog2 'h0)) begin
                regs[waddr]         <= wdata;
            end
        end
    end

    /*Part.3 读端口1*/
    always @(*) begin
        if (rst == `RstEnable) begin
            rdata1                  <= `ZeroWord;
        end else if (raddr1 == `RegNumLog2 'h0) begin
            rdata1                  <= `ZeroWord;
        end else if ((raddr1 == waddr) && (we == `WriteEnable) && (re1 == `ReadEnable)) begin
            rdata1                  <= wdata;
        end else if(re1 == `ReadEnable) begin
            rdata1                  <= regs[raddr1];
        end else begin
            rdata1                  <= `ZeroWord;
        end
    end

    /*Part.4 读端口2*/
    always @(*) begin
        if (rst == `RstEnable) begin
            rdata2                  <= `ZeroWord;
        end else if (raddr2 == `RegNumLog2 'h0) begin
            rdata2                  <= `ZeroWord;
        end else if ((raddr2 == waddr) && (we == `WriteEnable) && (re2 == `ReadEnable)) begin
            rdata2                  <= wdata;
        end else if(re2 == `ReadEnable) begin
            rdata2                  <= regs[raddr2];
        end else begin
            rdata2                  <= `ZeroWord;
        end
    end
    
endmodule