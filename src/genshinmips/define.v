//全局
`define RstEnable 1'b1
`define RstDisable 1'b0
`define ZeroWord 32'h00000000
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define ReadEnable 1'b1
`define ReadDisable 1'b0
`define AluOpBus 5:0
`define AluSelBus 2:0
`define InstValid 1'b0
`define InstInvalid 1'b1
`define Stop 1'b1
`define NoStop 1'b0
`define InDelaySlot 1'b1
`define NotInDelaySlot 1'b0
`define Branch 1'b1
`define NotBranch 1'b0
`define InterruptAssert 1'b1
`define InterruptNotAssert 1'b0
`define TrapAssert 1'b1
`define TrapNotAssert 1'b0
`define True_v 1'b1
`define False_v 1'b0
`define ChipEnable 1'b1
`define ChipDisable 1'b0


/*定义OP字段*/
`define     R_OP            6'b000000       // R型指令的OP
`define     SPECIAL_OP      6'b000001       // 特殊指令的OP

`define     ADDI_OP         6'b001000       // ADDI
`define     ADDIU_OP        6'b001001       // ADDIU
`define     SLTI_OP         6'b001010       // SLTI
`define     SLTIU_OP        6'b001011       // SLTIU
`define     MUL_OP          6'b011100       // MUL

`define     ANDI_OP         6'b001100       // ANDI
`define     LUI_OP          6'b001111       // LUI
`define     ORI_OP          6'b001101       // ORI
`define     XORI_OP         6'b001110       // XORI

`define     BEQ_OP          6'b000100       // BEQ
`define     BNE_OP          6'b000101       // BNE
`define     BGTZ_OP         6'b000111       // BGTZ
`define     BLEZ_OP         6'b000110       // BLEZ
`define     J_OP            6'b000010       // J
`define     JAL_OP          6'b000011       // JAL 

`define     LB_OP           6'b100000       // LB
`define     LW_OP           6'b100011       // LW
`define     SB_OP           6'b101000       // SB
`define     SW_OP           6'b101011       // SW


/*定义FUNC字段*/
`define     ADD_FUNC        6'b100000       // ADD
`define     ADDU_FUNC       6'b100001       // ADDU
`define     SUB_FUNC        6'b100010       // SUB
`define     SUBU_FUNC       6'b100011       // SUBU
`define     SLT_FUNC        6'b101010       // SLT
`define     SLTU_FUNC       6'b101011       // SLTU
`define     MUL_FUNC        6'b000010       // MUL

`define     AND_FUNC        6'b100100       // AND
`define     OR_FUNC         6'b100101       // OR
`define     XOR_FUNC        6'b100110       // XOR
`define     NOR_FUNC        6'b100111       // NOR

`define     SLL_FUNC        6'b000000       // SLL
`define     SLLV_FUNC       6'b000100       // SLLV
`define     SRA_FUNC        6'b000011       // SRA
`define     SRAV_FUNC       6'b000111       // SRAV
`define     SRL_FUNC        6'b000010       // SRL
`define     SRLV_FUNC       6'b000110       // SRLV

`define     JR_FUNC         6'b001000       // JR
`define     JALR_FUNC       6'b001001       // JALR


/*其他需要特殊判断的指令*/
`define     BGEZ_RT         5'b00001        // BGEZ
`define     BLTZ_RT         5'b00000        // BLTZ
`define     BGEZAL_RT       5'b10001        // BGEZAL
`define     BLTZAL_RT       5'b10000        // BLTZAL


/*定义EX阶段的操作类型*/
`define     EXE_NOP_OP      6'b000000       // 空
`define     EXE_AND_OP      6'b000001       // 按位与
`define     EXE_OR_OP       6'b000010       // 按位或
`define     EXE_XOR_OP      6'b000011       // 按位异或
`define     EXE_NOR_OP      6'b000100       // 按位或非

`define     EXE_SLL_OP      6'b000101       // 逻辑左移
`define     EXE_SRL_OP      6'b000110       // 逻辑右移
`define     EXE_SRA_OP      6'b000111       // 算数右移

`define     EXE_SLT_OP      6'b001000       // 小于则置位
`define     EXE_SLTU_OP     6'b001001       // 无符号小于则置位
`define     EXE_ADD_OP      6'b001010       // 加法
`define     EXE_SUB_OP      6'b001011       // 减法
`define     EXE_MUL_OP      6'b001100       // 乘法

`define     EXE_JAL_OP      6'b001101       // 跳转并链接

`define     EXE_LB_OP       6'b001110       // LB
`define     EXE_LW_OP       6'b001111       // LW
`define     EXE_SB_OP       6'b010000       // SB
`define     EXE_SW_OP       6'b010001       // SW


//指令存储器inst_rom
`define InstAddrBus 31:0
`define InstBus 31:0
`define InstMemNum 131071
`define InstMemNumLog2 17

//数据存储器data_ram
`define DataAddrBus 31:0
`define DataBus 31:0
`define DataMemNum 131071
`define DataMemNumLog2 17
`define ByteWidth 7:0

//通用寄存器regfile
`define RegAddrBus 4:0
`define RegBus 31:0
`define RegWidth 32
`define DoubleRegWidth 64
`define DoubleRegBus 63:0
`define RegNum 32
`define RegNumLog2 5
`define NOPRegAddr 5'b00000

`define PC_BEGIN_ADDR 32'h8000_0000

`define SerialState 32'hBFD003FC    //串口状态地址
`define SerialData  32'hBFD003F8    //串口数据地址

`define BaseRamStart 32'h8000_0000    //baseram开始地址
`define BaseRam_ExtRam  32'h8040_0000    //baseram结束/exitram开始地址
`define ExtRamEnd 32'h8080_0000    //exitram结束地址
