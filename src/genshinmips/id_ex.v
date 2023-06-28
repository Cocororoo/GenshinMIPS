`include "define.v"

/*
ID/EX模块：将译码阶段取得的运算类型、源操作数、待写入目的寄存器地址等在下一个时钟传递到流水线执行阶段
*/

module id_ex(
    input wire                  clk,
    input wire                  rst,

    //从译码阶段传递过来的信息
    input wire [`AluOpBus]      id_aluop,
    input wire [`AluSelBus]     id_alusel,
    input wire [`RegBus]        id_reg1,
    input wire [`RegBus]        id_reg2,
    input wire [`RegAddrBus]    id_wd,
    input wire                  id_wreg,

    input wire [5:0]            stall,

    input  wire [`RegBus]       id_link_address,
    input  wire                 id_is_in_delayslot,
    input  wire                 next_inst_in_delayslot_i,

    input  wire [`RegBus]       id_inst,

    //传递到执行阶段的信息
    output reg [`AluOpBus]      ex_aluop,
    output reg  [`AluSelBus]    ex_alusel,
    output reg  [`RegBus]       ex_reg1,
    output reg  [`RegBus]       ex_reg2,
    output reg  [`RegAddrBus]   ex_wd,
    output reg                  ex_wreg,

    output reg [`RegBus]        ex_link_address,
    output reg                  ex_is_in_delayslot,
    output reg                  is_in_delayslot_o,

    output reg [`RegBus]        ex_inst
);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            ex_aluop            <= `EXE_NOP_OP;
            ex_alusel           <= `EXE_RES_NOP;
            ex_reg1             <= `ZeroWord;
            ex_reg2             <= `ZeroWord;
            ex_wd               <= `NOPRegAddr;
            ex_wreg             <= `WriteDisable;

            ex_link_address     <= `ZeroWord;
            ex_is_in_delayslot  <= `NotInDelaySlot;
            is_in_delayslot_o   <= `NotInDelaySlot;
        end else if (stall[2] == `Stop && stall[3] == `NoStop) begin
            ex_aluop            <= `EXE_NOP_OP;
            ex_alusel           <= `EXE_RES_NOP;
            ex_reg1             <= `ZeroWord;
            ex_reg2             <= `ZeroWord;
            ex_wd               <= `NOPRegAddr;
            ex_wreg             <= `WriteDisable;

            ex_link_address     <= `ZeroWord;
            ex_is_in_delayslot  <= `NotInDelaySlot;
        end else if (stall[2] == `NoStop) begin
            ex_aluop            <= id_aluop;
            ex_alusel           <= id_alusel;
            ex_reg1             <= id_reg1;
            ex_reg2             <= id_reg2;
            ex_wd               <= id_wd;
            ex_wreg             <= id_wreg;

            ex_link_address     <= id_link_address;
            ex_is_in_delayslot  <= id_is_in_delayslot;
            is_in_delayslot_o   <= next_inst_in_delayslot_i;

            ex_inst             <= id_inst;
        end
    end
endmodule