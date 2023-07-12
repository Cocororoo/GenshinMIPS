`include "define.v"

/*
MEM模块：数据存储器
*/

module mem(
    input wire                  rst,
    input wire [`InstAddrBus]   debug_pc_i, 

    //来自EX阶段的信息
    input wire [`RegAddrBus]    waddr_i,       //访存阶段的指令要写入的寄存器地址
    input wire                  we_i,     //访存阶段的指令写入使能
    input wire [`RegBus]        wdata_i,    //访存阶段的指令写入值

    input wire [`AluOpBus]      aluop_i,
    input wire [`RegBus]        mem_addr_i,
    input wire [`RegBus]        mem_data_i,

    //来自外部RAM信息（LB，LW）
    input wire [`RegBus]        ram_data_i,

    //访存阶段的结果
    output reg [`RegAddrBus]    waddr_o,       //访存阶段的指令最终要写入的寄存器地址
    output reg                  we_o,     //访存阶段的指令最终写入使能
    output reg [`RegBus]        wdata_o,    //访存阶段的指令最终写入值

    //送到RAM的信息
    output reg [`RegBus]        mem_addr_o,
    output wire                 mem_we_o,
    output reg [3:0]            mem_sel_o,  //字节选择
    output reg [`RegBus]        mem_data_o,
    output reg                  mem_ce_o,   //RAM使能

	output wire 				stallreq
);

	assign  stallreq    = (mem_addr_i >= 32'h80000000) 
                        && (mem_addr_i < 32'h80400000);

    wire [`RegBus]              zero32;
    reg                         mem_we;

    assign                      mem_we_o = mem_we;
    assign                      zero32 = `ZeroWord;

    always @ (*) begin
		waddr_o                = `NOPRegAddr;
		we_o              = `WriteDisable;
		wdata_o             = `ZeroWord;

		mem_addr_o          = `ZeroWord;
		mem_we              =`WriteDisable;
		mem_sel_o           = 4'b0000;
		mem_data_o          = `ZeroWord;
		mem_ce_o            = `ChipDisable;
        if (rst == `RstEnable) begin
            waddr_o                = `NOPRegAddr;
            we_o              = `WriteDisable;
            wdata_o             = `ZeroWord;

            mem_addr_o          = `ZeroWord;
            mem_we              =`WriteDisable;
            mem_sel_o           = 4'b0000;
            mem_data_o          = `ZeroWord;
            mem_ce_o            = `ChipDisable;
        end else begin
            waddr_o                = waddr_i;
            we_o              = we_i;
            wdata_o             = wdata_i;

            mem_we              = `WriteDisable;
			mem_addr_o          = `ZeroWord;
			mem_sel_o           = 4'b1111;
			mem_ce_o            = `ChipDisable;

			case (aluop_i)
				`EXE_LB_OP:		begin
					mem_addr_o          = mem_addr_i;
					mem_we              = `WriteDisable;
					mem_ce_o            = `ChipEnable;
					case (mem_addr_i[1:0])
						2'b00:	begin
							wdata_o     = {{24{ram_data_i[31]}},ram_data_i[31:24]};
							mem_sel_o   = 4'b1000;
						end
						2'b01:	begin
							wdata_o     = {{24{ram_data_i[23]}},ram_data_i[23:16]};
							mem_sel_o   = 4'b0100;
						end
						2'b10:	begin
							wdata_o     = {{24{ram_data_i[15]}},ram_data_i[15:8]};
							mem_sel_o   = 4'b0010;
						end
						2'b11:	begin
							wdata_o     = {{24{ram_data_i[7]}},ram_data_i[7:0]};
							mem_sel_o   = 4'b0001;
						end
						default:	begin
							wdata_o     = `ZeroWord;
						end
					endcase
				end
				`EXE_LW_OP:		begin
					mem_addr_o          = mem_addr_i;
					mem_we              = `WriteDisable;
					wdata_o             = ram_data_i;
					mem_sel_o           = 4'b1111;
					mem_ce_o            = `ChipEnable;		
				end
				`EXE_SB_OP:		begin
					mem_addr_o          = mem_addr_i;
					mem_we              = `WriteEnable;
					mem_data_o          = {mem_data_i[7:0],mem_data_i[7:0],mem_data_i[7:0],mem_data_i[7:0]};
					mem_ce_o            = `ChipEnable;
					case (mem_addr_i[1:0])
						2'b00:	begin
							mem_sel_o   = 4'b1000;
						end
						2'b01:	begin
							mem_sel_o   = 4'b0100;
						end
						2'b10:	begin
							mem_sel_o   = 4'b0010;
						end
						2'b11:	begin
							mem_sel_o   = 4'b0001;	
						end
						default:	begin
							mem_sel_o   = 4'b0000;
						end
					endcase				
				end
				`EXE_SW_OP:		begin
					mem_addr_o          = mem_addr_i;
					mem_we              = `WriteEnable;
					mem_data_o          = mem_data_i;
					mem_sel_o           = 4'b1111;	
					mem_ce_o            = `ChipEnable;		
				end
				default:		begin
          			//什么也不做
				end
            endcase // case aluop_i
        end // else
    end // always

endmodule