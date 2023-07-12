`include "define.v"

/*
ID/EX模块：将译码阶段取得的运算类型、源操作数、待写入目的寄存器地址等在下一个时钟传递到流水线执行阶段
*/

module id_ex(
    input wire                  clk,
    input wire                  rst,

    input wire [`InstAddrBus]   debug_pc_i, 
    output reg  [`InstAddrBus]  debug_pc_o, 

    //从ID阶段传递过来的信息
    input wire [`AluOpBus]      id_aluop,
    input wire [`AluSelBus]     id_alusel,
    input wire [`RegBus]        id_reg1_data,
    input wire [`RegBus]        id_reg2_data,
    input wire [`RegAddrBus]    id_waddr,
    input wire                  id_we,

    input  wire [`RegBus]       id_link_addr,

    input  wire [`RegBus]       id_inst,

    //传递到EX阶段的信息
    output reg [`AluOpBus]      ex_aluop,
    output reg  [`AluSelBus]    ex_alusel,
    output reg  [`RegBus]       ex_reg1_data,
    output reg  [`RegBus]       ex_reg2_data,
    output reg  [`RegAddrBus]   ex_waddr,
    output reg                  ex_we,

    output reg [`RegBus]        ex_link_addr,


    output reg [`RegBus]        ex_inst,

    input wire [5:0]            stall
);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            ex_aluop            <= `EXE_NOP_OP;
            ex_alusel           <= `EXE_RES_NOP;
            ex_reg1_data        <= `ZeroWord;
            ex_reg2_data        <= `ZeroWord;
            ex_waddr            <= `NOPRegAddr;
            ex_we               <= `WriteDisable;

            ex_link_addr        <= `ZeroWord;
            debug_pc_o          <= `ZeroWord;
        end else if (stall[2] == `Stop && stall[3] == `NoStop) begin
            ex_aluop            <= `EXE_NOP_OP;
            ex_alusel           <= `EXE_RES_NOP;
            ex_reg1_data        <= `ZeroWord;
            ex_reg2_data        <= `ZeroWord;
            ex_waddr            <= `NOPRegAddr;
            ex_we               <= `WriteDisable;

            ex_link_addr        <= `ZeroWord;
            debug_pc_o          <= `ZeroWord;
        end else if (stall[2] == `NoStop) begin
            ex_aluop            <= id_aluop;
            ex_alusel           <= id_alusel;
            ex_reg1_data        <= id_reg1_data;
            ex_reg2_data        <= id_reg2_data;
            ex_waddr            <= id_waddr;
            ex_we               <= id_we;

            ex_link_addr        <= id_link_addr;

            ex_inst             <= id_inst;

            debug_pc_o          <= debug_pc_i;
        end
    end
endmodule