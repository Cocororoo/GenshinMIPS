`include "define.v"

module RAM_ctrl (
    input wire clk,
    input wire rst,

    //if阶段输入的信息和获得的指�?
    input    wire[31:0]  rom_addr_i,        //读取指令的地�?
    input    wire        rom_ce_i,          //指令存储器使能信�?
    output   reg [31:0]  rom_data_o,        //获取到的指令

    //mem阶段传�?�的信息和取得的数据
    output   reg[31:0]   ram_data_o,        //读取的数�?
    input    wire[31:0]  mem_addr_i,        //读（写）地址
    input    wire[31:0]  mem_data_i,        //写入的数�?
    input    wire        mem_we,          //写使能，高有�?
    input    wire[3:0]   mem_sel,         //字节选择信号，高有效


    //BaseRAM信号
    inout    wire[31:0]  base_ram_data,     //BaseRAM数据
    output   reg [19:0]  base_ram_addr,     //BaseRAM地址
    output   reg [3:0]   base_ram_be_n,     //BaseRAM字节使能，低有效�?
    output   reg         base_ram_ce_n,     //BaseRAM片�?�，低有�?
    output   reg         base_ram_oe_n,     //BaseRAM读使能，低有�?
    output   reg         base_ram_we_n,     //BaseRAM写使能，低有�?

    //ExtRAM信号
    inout    wire[31:0]  ext_ram_data,      //ExtRAM数据
    output   reg [19:0]  ext_ram_addr,      //ExtRAM地址
    output   reg [3:0]   ext_ram_be_n,      //ExtRAM字节使能，低有效�?
    output   reg         ext_ram_ce_n,      //ExtRAM片�?�，低有�?
    output   reg         ext_ram_oe_n,      //ExtRAM读使能，低有�?
    output   reg         ext_ram_we_n,      //ExtRAM写使能，低有�?

    //直连串口信号
    output   wire        txd,                //直连串口发�?�端
    input    wire        rxd,                //直连串口接收�?

    output   wire[1:0]   state                
);

wire [7:0]  RxD_data;          
wire [7:0]  TxD_data;           
wire        RxD_data_ready;     
wire        TxD_busy;          
wire        TxD_start;          
wire        RxD_clear;          

wire        RxD_FIFO_wr_en;
wire        RxD_FIFO_full;
wire [7:0]  RxD_FIFO_din;
reg         RxD_FIFO_rd_en;
wire        RxD_FIFO_empty;
wire [7:0]  RxD_FIFO_dout;

reg         TxD_FIFO_wr_en;
wire        TxD_FIFO_full;
reg  [7:0]  TxD_FIFO_din;
wire        TxD_FIFO_rd_en;
wire        TxD_FIFO_empty;
wire [7:0]  TxD_FIFO_dout;

//串口实例化模块，波特�?9600
async_receiver #(.ClkFrequency(60200000),.Baud(9600))   
                ext_uart_r(
                   .clk(clk),                           //外部时钟信号
                   .RxD(rxd),                           //外部串行信号输入
                   .RxD_data_ready(RxD_data_ready),     //数据接收到标�?
                   .RxD_clear(RxD_clear),               //清除接收标志
                   .RxD_data(RxD_data)                  //接收到的�?字节数据
                );

async_transmitter #(.ClkFrequency(60200000),.Baud(9600)) 
                    ext_uart_t(
                      .clk(clk),                        //外部时钟信号
                      .TxD(txd),                        //串行信号输出
                      .TxD_busy(TxD_busy),              //发�?�器忙状态指�?
                      .TxD_start(TxD_start),            //�?始发送信�?
                      .TxD_data(TxD_data)               //待发送的数据
                    );


fifo_generator_0 RXD_FIFO (
    .rst(rst),
    .clk(clk),
    .wr_en(RxD_FIFO_wr_en),   
    .din(RxD_FIFO_din),        
    .full(RxD_FIFO_full),    

    .rd_en(RxD_FIFO_rd_en),   
    .dout(RxD_FIFO_dout),   
    .empty(RxD_FIFO_empty)    
);

fifo_generator_0 TXD_FIFO (
    .rst(rst),
    .clk(clk),
    .wr_en(TxD_FIFO_wr_en),     
    .din(TxD_FIFO_din),         
    .full(TxD_FIFO_full),       

    .rd_en(TxD_FIFO_rd_en),     
    .dout(TxD_FIFO_dout),      
    .empty(TxD_FIFO_empty)     
);

//内存映射
wire is_SerialState = (mem_addr_i ==  `SerialState); 
wire is_SerialData  = (mem_addr_i == `SerialData);
wire is_base_ram    = (mem_addr_i >= `BaseRamStart) 
                    && (mem_addr_i < `BaseRam_ExtRam);
wire is_ext_ram     = (mem_addr_i >= `BaseRam_ExtRam)
                    && (mem_addr_i < `ExtRamEnd);

reg [31:0] serial_o;        //串口输出数据
wire[31:0] base_ram_o;      //baseram输出数据
wire[31:0] ext_ram_o;       //extram输出数据

assign state = {!RxD_FIFO_empty,!TxD_FIFO_full};

assign TxD_FIFO_rd_en = TxD_start;
assign TxD_start = (!TxD_busy) && (!TxD_FIFO_empty);
assign TxD_data = TxD_FIFO_dout;

assign RxD_FIFO_wr_en = RxD_data_ready;
assign RxD_FIFO_din = RxD_data;
assign RxD_clear = RxD_data_ready && (!RxD_FIFO_full);

always @(*) begin
    TxD_FIFO_wr_en = `WriteDisable;
    TxD_FIFO_din = 8'h00;
    RxD_FIFO_rd_en = `ReadDisable;
    serial_o = `ZeroWord;
    if(is_SerialState) begin            
        TxD_FIFO_wr_en = `WriteDisable;
        TxD_FIFO_din = 8'h00;
        RxD_FIFO_rd_en = `ReadDisable;
        serial_o = {{30{1'b0}}, state};
    end 
    else if(is_SerialData) begin        
        if(mem_we == `WriteDisable) begin   
            TxD_FIFO_wr_en = `WriteDisable;
            TxD_FIFO_din = 8'h00;
            RxD_FIFO_rd_en = `ReadEnable;
            serial_o = {{24{1'b0}}, RxD_FIFO_dout};
        end
        else begin                              
            TxD_FIFO_wr_en = `WriteEnable;
            TxD_FIFO_din = mem_data_i[7:0];
            RxD_FIFO_rd_en = `ReadDisable;
            serial_o = `ZeroWord;
        end
    end
    else begin
        TxD_FIFO_wr_en = `WriteDisable;
        TxD_FIFO_din = 8'h00;
        RxD_FIFO_rd_en = `ReadDisable;
        serial_o = `ZeroWord;
    end
end



assign base_ram_data = is_base_ram ? ((mem_we == `WriteEnable) ? mem_data_i : 32'hzzzzzzzz) : 32'hzzzzzzzz;
assign base_ram_o = base_ram_data;      

always @(*) begin
    base_ram_addr = 20'h00000;
    base_ram_be_n = 4'b0000;
    base_ram_ce_n = 1'b0;
    base_ram_oe_n = 1'b1;
    base_ram_we_n = 1'b1;
    rom_data_o = `ZeroWord;
    if(is_base_ram) begin           
        base_ram_addr = mem_addr_i[21:2];   
        base_ram_be_n = !mem_sel;
        base_ram_ce_n = 1'b0;
        base_ram_oe_n = mem_we;
        base_ram_we_n = !mem_we;
        rom_data_o = `ZeroWord;
    end else begin                  
        base_ram_addr = rom_addr_i[21:2];   
        base_ram_be_n = 4'b0000;
        base_ram_ce_n = 1'b0;
        base_ram_oe_n = 1'b0;
        base_ram_we_n = 1'b1;
        rom_data_o = base_ram_o;
    end
end

assign ext_ram_data = is_ext_ram ? ((mem_we == `WriteEnable) ? mem_data_i : 32'hzzzzzzzz) : 32'hzzzzzzzz;
assign ext_ram_o = ext_ram_data;

always @(*) begin
    ext_ram_addr = 20'h00000;
    ext_ram_be_n = 4'b0000;
    ext_ram_ce_n = 1'b0;
    ext_ram_oe_n = 1'b1;
    ext_ram_we_n = 1'b1;
    if(is_ext_ram) begin
        ext_ram_addr = mem_addr_i[21:2];    
        ext_ram_be_n = !mem_sel;
        ext_ram_ce_n = 1'b0;
        ext_ram_oe_n = mem_we;
        ext_ram_we_n = !mem_we;
    end else begin
        ext_ram_addr = 20'h00000;
        ext_ram_be_n = 4'b0000;
        ext_ram_ce_n = 1'b0;
        ext_ram_oe_n = 1'b1;
        ext_ram_we_n = 1'b1;
    end
end

always @(*) begin
    ram_data_o = `ZeroWord;
    if(is_SerialState || is_SerialData ) begin
        ram_data_o = serial_o;
    end else if (is_base_ram) begin
        case (mem_sel)
            4'b0001: begin
                ram_data_o = {{24{base_ram_o[7]}}, base_ram_o[7:0]};
            end
            4'b0010: begin
                ram_data_o = {{24{base_ram_o[15]}}, base_ram_o[15:8]};
            end
            4'b0100: begin
                ram_data_o = {{24{base_ram_o[23]}}, base_ram_o[23:16]};
            end
            4'b1000: begin
                ram_data_o = {{24{base_ram_o[31]}}, base_ram_o[31:24]};
            end
            4'b1111: begin
                ram_data_o = base_ram_o;
            end
            default: begin
                ram_data_o = base_ram_o;
            end
        endcase
    end else if (is_ext_ram) begin
        case (mem_sel)
            4'b0001: begin
                ram_data_o = {{24{ext_ram_o[7]}}, ext_ram_o[7:0]};
            end
            4'b0010: begin
                ram_data_o = {{24{ext_ram_o[15]}}, ext_ram_o[15:8]};
            end
            4'b0100: begin
                ram_data_o = {{24{ext_ram_o[23]}}, ext_ram_o[23:16]};
            end
            4'b1000: begin
                ram_data_o = {{24{ext_ram_o[31]}}, ext_ram_o[31:24]};
            end
            4'b1111: begin
                ram_data_o = ext_ram_o;
            end
            default: begin
                ram_data_o = ext_ram_o;
            end
        endcase
    end else begin
        ram_data_o = `ZeroWord;
    end
end


endmodule 