`include "define.v"

module ctrl (

    input wire rst,

    input wire stallreq_from_id,

    input  wire       stallreq_from_ex,
    output reg  [5:0] stall

);

  // stall[0] -> [5] ：分别控制取值地址PC是否不变，取指、译码、执行、访存、回写是否暂停，“1”表暂停
  always @(*) begin
    if (rst == `RstEnable) begin
      stall <= 6'b000000;
    end else if (stallreq_from_ex == `Stop) begin
      stall <= 6'b001111;  // PC不变，取值、译码、执行暂停，访存、回写继续
    end else if (stallreq_from_id == `Stop) begin
      stall <= 6'b000111;
    end else begin
      stall <= 6'b000000;
    end  //if
  end  //always


endmodule
