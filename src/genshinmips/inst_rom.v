`include "define.v"

/*
ROM模块：只读存储器，提供指�?
**/

module inst_rom(
    input wire                  ce,
    input wire [`InstAddrBus]   addr,
    output reg [`InstBus]       inst
);

    reg [`InstBus]              inst_mem [0: 35];

    //使用inst_rom.data文件初始化指令存储器
    initial $readmemh ("D:\\CodingNow\\Verilog\\OpenMIPS\\data\\inst_rom.data", inst_mem);

    //根据地址输出ROM对应元素
    always @ (*) begin
        if (ce == `ChipDisable) inst <= `ZeroWord;
        else                    inst <= inst_mem[addr[`InstMemNumLog2+1:2]];
    end


endmodule