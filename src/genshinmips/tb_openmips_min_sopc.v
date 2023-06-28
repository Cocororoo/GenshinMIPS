`include "define.v"
`include "openmips_min_sopc.v"

`timescale 1ns/1ps

module tb_openmips_min_sopc();

reg                     CLOCK_50;
reg                     rst;

//CLOCK_50每隔10ns翻转一次，一个周期为20ns，对应频率50MHz
initial begin
    CLOCK_50            = 1'b0;
    forever begin
        #10 CLOCK_50    = ~CLOCK_50;
    end
end

//最初时刻，复位，195ns时复位失效，最小SOPC开始运行
initial begin
    $dumpfile("../vcd/wave_min_sopc.vcd");
    $dumpvars;
    rst                 = `RstEnable;
    #195 rst            = `RstDisable;
    #6000               $finish;
end

openmips_min_sopc openmips_min_sopc0 (
    .clk(CLOCK_50),
    .rst(rst)
);

endmodule