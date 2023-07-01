`define SerialStat 32'hBFD003FC
`define SerialDate 32'hBFD003F8

module RAM_ctrl (
    input wire rst,
    input wire clk_50M, //50MHz 时钟输入

    // 取指令
    input  wire [31:0] rom_addr_i,  // 读取指令的地址
    input  wire        ce_i,        // 使能信号
    output reg  [31:0] rom_data_o,  // 获取到的指令

    // 存储数据线
    output reg  [31:0] ram_data_o,
    input  wire [31:0] ram_addr_i,
    input  wire [31:0] ram_data_i,
    input  wire        ram_we_i_n,  // 写使能，低有效
    input  wire [ 3:0] ram_sel_i,
    input  wire        ram_ce_i,

    //BaseRAM信号

    inout  wire [31:0] base_ram_data,  //BaseRAM数据，低8位与CPLD串口控制器共享
    output reg  [19:0] base_ram_addr,  //BaseRAM地址

    output   reg [3:0]   base_ram_be_n,          //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output reg base_ram_ce_n,  //BaseRAM片选，低有效
    output reg base_ram_oe_n,  //BaseRAM读使能，低有效
    output reg base_ram_we_n,  //BaseRAM写使能，低有效

    //ExtRAM信号
    inout  wire [31:0] ext_ram_data,  //ExtRAM数据
    output reg  [19:0] ext_ram_addr,  //ExtRAM地址

    output   reg [3:0]   ext_ram_be_n,           //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output reg ext_ram_ce_n,  //ExtRAM片选，低有效
    output reg ext_ram_oe_n,  //ExtRAM读使能，低有效
    output reg ext_ram_we_n  //ExtRAM写使能，低有效
);

  /* CPU 连接协同模块 */

  // 处理读取或者写入的数据范围
  wire is_SerialStat = (ram_addr_i == `SerialStat);
  wire is_SerialDate = (ram_addr_i == `SerialDate);
  wire is_base_ram = is_SerialStat != 1'b1 && is_SerialDate != 1'b1 && (ram_addr_i >= 32'h80000000) &&   (ram_addr_i < 32'h80400000);
  wire is_ext_ram = is_SerialStat != 1'b1 && is_SerialDate != 1'b1 &&  (ram_addr_i < 32'h80800000) && (ram_addr_i >= 32'h80400000);

  wire [31:0] base_ram_o;
  wire [31:0] ext_ram_o;

  // BaseRam 管理指令或者数据的存取
  assign base_ram_data = is_base_ram ? ((ram_we_i_n) ? 32'hzzzzzzzz : ram_data_i) : 32'hzzzzzzzz;
  assign base_ram_o    = base_ram_data;  // 在读取模式下，读取到的BaseRam数据

  // 处理BaseRam
  // 在需要从BaseRam中获取或者写入数据的时候，往往认为CPU会暂停流水线（1个时钟周期）
  always @(*) begin
    if (rst) begin
      base_ram_addr <= 20'h0000_0;
      base_ram_be_n <= 4'b1111;
      base_ram_ce_n <= 1'b1;
      base_ram_oe_n <= 1'b1;
      base_ram_we_n <= 1'b1;
      rom_data_o <= 32'h0000_0000;
    end else begin
      if (is_base_ram) begin  // 涉及到BaseRam的相关数据操作，默认暂停流水线
        base_ram_addr <= ram_addr_i[21:2];
        base_ram_be_n <= ram_sel_i;
        base_ram_ce_n <= 1'b0;
        base_ram_oe_n <= !ram_we_i_n;
        base_ram_we_n <= ram_we_i_n;
      end else begin  // 不涉及到BaseRam的相关数据操作，继续取指令
        base_ram_addr <= rom_addr_i[21:2];
        base_ram_be_n <= 4'b0000;
        base_ram_ce_n <= 1'b0;
        base_ram_oe_n <= 1'b0;
        base_ram_we_n <= 1'b1;
      end
      rom_data_o <= base_ram_o;
    end
  end


  // 处理ExtRam
  assign ext_ram_data = (ram_we_i_n) ? 32'hzzzzzzzz : ram_data_i;
  assign ext_ram_o = ext_ram_data;

  always @(*) begin
    if (rst) begin
      ext_ram_addr <= 20'h00000;
      ext_ram_be_n <= 4'b1111;
      ext_ram_ce_n <= 1'b1;
      ext_ram_oe_n <= 1'b1;
      ext_ram_we_n <= 1'b1;
    end else begin
      if (is_ext_ram) begin  // 涉及到extRam的相关数据操作
        ext_ram_addr <= ram_addr_i[21:2];
        ext_ram_be_n <= ram_sel_i;
        ext_ram_ce_n <= 1'b0;
        ext_ram_oe_n <= !ram_we_i_n;
        ext_ram_we_n <= ram_we_i_n;
      end else begin  //
        ext_ram_addr <= 20'h00000;
        ext_ram_be_n <= 4'b1111;
        ext_ram_ce_n <= 1'b1;
        ext_ram_oe_n <= 1'b1;
        ext_ram_we_n <= 1'b1;
      end
    end
  end


  // 模块，确认输出的数据
  always @(*) begin
    if (rst) begin
      ram_data_o <= 32'h0000_0000;
    end else begin
      if (is_base_ram) begin
        // ram_data_o <= base_ram_o;
        case (ram_sel_i)
          4'b1110: begin
            ram_data_o <= {{24{base_ram_o[7]}}, base_ram_o[7:0]};
          end
          4'b1101: begin
            ram_data_o <= {{24{base_ram_o[15]}}, base_ram_o[15:8]};
          end
          4'b1011: begin
            ram_data_o <= {{24{base_ram_o[23]}}, base_ram_o[23:16]};
          end
          4'b0111: begin
            ram_data_o <= {{24{base_ram_o[31]}}, base_ram_o[31:24]};
          end
          4'b0000: begin
            ram_data_o <= base_ram_o;
          end
          default: begin
            ram_data_o <= base_ram_o;
          end
        endcase
      end else if (is_ext_ram) begin
        // ram_data_o <= ext_ram_o;
        case (ram_sel_i)
          4'b1110: begin
            ram_data_o <= {{24{ext_ram_o[7]}}, ext_ram_o[7:0]};
          end
          4'b1101: begin
            ram_data_o <= {{24{ext_ram_o[15]}}, ext_ram_o[15:8]};
          end
          4'b1011: begin
            ram_data_o <= {{24{ext_ram_o[23]}}, ext_ram_o[23:16]};
          end
          4'b0111: begin
            ram_data_o <= {{24{ext_ram_o[31]}}, ext_ram_o[31:24]};
          end
          4'b0000: begin
            ram_data_o <= ext_ram_o;
          end
          default: begin
            ram_data_o <= ext_ram_o;
          end
        endcase
      end else begin
        ram_data_o <= 32'h0000_0000;
      end
    end
  end

endmodule
