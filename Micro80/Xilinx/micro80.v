`timescale 1ns / 1ps

//`define SDRAM
`define SRAM
`define DEBUG

module micro80(
	input wire clk,
	input wire rst,
	input wire HOLD,
	//HDMI
	output wire[2:0]tmdsp,
	output wire[2:0]tmdsn,
	output wire tmdscp,
    output wire tmdscn,
`ifdef SDRAM
	//SDRAM
	output wire SDRAM_CLK,
	output wire SDRAM_CKE,
	output wire SDRAM_CS,
	output wire SDRAM_RAS,
	output wire SDRAM_CAS,
	output wire SDRAM_WE,
	output wire[1:0] SDRAM_DQM,
	output wire[1:0] SDRAM_BS,
	output wire[12:0] SDRAM_ADD,
	inout wire[15:0] SDRAM_DQ,
`endif
`ifdef SRAM
	//SRAM
	output wire[18:0]ER_ADD,
	inout wire[7:0]ER_D,
	output wire ER_CS,
	output wire ER_OE,
	output wire ER_WE,
	output wire ER_BH,
	output wire ER_BL,
`endif
	/*
	//PS/2
	//input wire PS2_CLK,
	//input wire PS2_DAT,
	*/
	//USB_Keyboard
	input wire KB_MOSI,
	input wire KB_SCK,
	input wire KB_CS,
	input wire KB_LATCH,
	//SPI Flash
	output wire SPI_CS,
	output wire MOSI,
	output wire SCK,
	input wire MISO,
	//CP/M
	input wire mode,
	input wire color,
`ifdef DEBUG
	//Debug
	output wire[7:0]SEG,
	output wire[7:0]RAZR,
	output wire LED,	
`endif
	//UART
	output wire UART_TX,
	input wire UART_RX
);

//CPM
wire[7:0]PFF;

//Clocking
wire CLK2_5,CLK5,CLK10,CLK20,CLK65,CLK650,CLK100,CPU_CLK;

main_pll mpl(
    .clk_in1(clk),
    .resetn(1'b1),
    .clk_out1(CLK20),
    .clk_out2(CLK65),
    .clk_out3(CLK650),
    .clk_out4(CLK100)
    );

reg[22:0] div;
always@(posedge CLK20) div <= div + 1;

assign CLK2_5 = div[2];
assign CLK5 = div[1];
assign CLK10 = div[0];

//CPU
wire[15:0]CPU_ADD;
wire[7:0]CPU_DI,CPU_DO,IO_DO;
wire MREQ,IORQ;
wire CRST;
//Programmer
wire PROG,PROGWE;
wire[18:0]PROGADD;
wire[7:0]PROGDO;
//I8080
wire RM,WM,RIO,WIO,DBIN,WO,HLDA,SYNC,F1,F2;

assign CRST = (rst & HOLD & ~PROG);
assign CPU_CLK = div[2];
assign F1 = div[2] & div[1];
assign F2 = ~div[2];

vm80a_core mcp
(
   .pin_clk(clk),
   .pin_f1(F1),
   .pin_f2(F2),
   .pin_reset(~CRST),
   .pin_a(CPU_ADD),
   .pin_dout(CPU_DO),
   .pin_din(CPU_DI),
   .pin_hold(1'b0),
   .pin_ready(1'b1),
   .pin_int(1'b0),
   .pin_wr_n(WO),
   .pin_dbin(DBIN),
   .pin_hlda(HLDA),
   .pin_sync(SYNC)
);

reg[7:0]i8080ctrl;
wire[7:0]CCTRL;

always@(negedge F1) if(SYNC == 1) i8080ctrl[7:0] <= CPU_DO[7:0];
	
assign CCTRL = i8080ctrl;

assign RIO = ~(DBIN & CCTRL[6]);
assign WIO = ~(CCTRL[4] & ~WO); 
assign RM = ~(DBIN & CCTRL[7]);
assign WM = ~(~CCTRL[4] & ~WO);

//Video
videocontroller mvc(
    .pixclk(CLK65),
    .hclk(CLK650),
    .rst(rst),
    .tmdsp(tmdsp),
    .tmdsn(tmdsn),
    .tmdscp(tmdscp),
    .tmdscn(tmdscn),
	.ADD(CPU_ADD),
	.DIN(CPU_DO),
	.WR(WM),
	.color(color)
	);

//Monitor
wire[18:0]MON_ADD,CPM_ADD;
wire[7:0]MON_DI;
wire MON_SEL;
reg start;						  

always@(posedge CPU_ADD[11] or negedge CRST)
	begin
		if(!CRST) start <= 0;
		else start <= 1;		
	end
	
assign MON_SEL = (CPU_ADD >= 16'hF800)? 1'b1 : 1'b0;

`ifdef SDRAM
//SDRAM
wire SDRAM_WR,SDRAM_RD,SDRAM_RDY,SDRAM_WAIT;
wire[23:0]SDRAM_A;
wire[15:0]SDRAM_DI,SDRAM_DO;

sdram msdram(
	.clk(CLK100),
	.rst(rst),
	.wr(SDRAM_WR),
	.rd(SDRAM_RD),
	.rdy(SDRAM_RDY),
	.SDWAIT(SDRAM_WAIT),
	.ADD(SDRAM_A),
	.DI(SDRAM_DI),
	.DO(SDRAM_DO),	
	//SDRAM
	.SDRAM_CLK(SDRAM_CLK),
	.SDRAM_CKE(SDRAM_CKE),
	.SDRAM_CS(SDRAM_CS),
	.SDRAM_RAS(SDRAM_RAS),
	.SDRAM_CAS(SDRAM_CAS),
	.SDRAM_WE(SDRAM_WE),
	.SDRAM_DQM(SDRAM_DQM),
	.SDRAM_BS(SDRAM_BS),
	.SDRAM_ADD(SDRAM_ADD),
	.SDRAM_DQ(SDRAM_DQ)
);
`endif

programmer mpg(
    .clk(clk),
`ifdef SDRAM		 
    .rst(rst & SDRAM_WAIT),
`endif	
`ifdef SRAM		 
    .rst(rst),
`endif	 
    .PROG(PROG),
    .SRAMADD(PROGADD),
    .SRAMDO(PROGDO),
    .SRAMWE(PROGWE),
	.SPI_CS(SPI_CS),
	.SPI_MOSI(MOSI),
	.SPI_MISO(MISO),
`ifdef SDRAM	
	.DEV_RDY(SDRAM_RDY),
`endif
	.SPI_SCK(SCK)
	);

//Keyboard
wire[7:0]KPA;
wire[6:0]KPB;
wire[2:0]KPC;

//keyboard mkb(.clk(clk),.rst(CRST),.clock(PS2_CLK),.dat(PS2_DAT),.PA(KPA), .PC(KPC),.PB(KPB));
keyboard_usb  mkbu(.rst(CRST),.MOSI(KB_MOSI),.SCK(KB_SCK),.CS(KB_CS),.LATCH(KB_LATCH),.PA(KPA),
						 .PC(KPC),.PB(KPB),.LED());


//SRAM
wire[7:0] ER_DI;
wire RAM_WE,MON_WE,CPM_WE;

assign MON_ADD = (start)? {3'b000,CPU_ADD[15:0]} : {8'b00011111,CPU_ADD[10:0]}; //
assign CPM_ADD = (CPU_ADD[15] == 1'b0)? {PFF[5:4],~PFF[2],PFF[3],~CPU_ADD[14:0]} : {3'b000,CPU_ADD[15:0]}; //PFF[0]
assign MON_WE = (CPU_ADD > 16'hF800)? 1'b1 : WM;
assign CPM_WE = (PFF[5:2] == 4'b0000 && CPU_ADD[15] == 0)? 1'b1 : WM;
assign RAM_WE = (mode)? CPM_WE : MON_WE;

`ifdef SDRAM	
assign SDRAM_A[23:0] = (PROG)? {5'b00000,PROGADD[18:0]} : ((mode)? {5'b00000,CPM_ADD} : {5'b00000,MON_ADD});
assign SDRAM_DI[15:0] = (PROG)? {8'hFF,PROGDO} : {8'hFF,CPU_DO};
assign SDRAM_WR = (PROG)? PROGWE : RAM_WE;
assign SDRAM_RD = (PROG)? 1'b1 : RM;
`endif

`ifdef SRAM	
assign ER_ADD[18:0] = (PROG)? PROGADD[18:0] : ((mode)? CPM_ADD : MON_ADD);
assign ER_D = (ER_WE == 0)? ER_DI : 8'bzzzzzzzz;
assign ER_DI = (PROG)? PROGDO : CPU_DO;
assign ER_WE = (PROG)? PROGWE : RAM_WE;
assign ER_OE = (PROG)? 1'b1 : RM;
assign ER_CS = (PROG)? 1'b0 : (RM & WM);

assign ER_BH = 1'b1;
assign ER_BL = 1'b0;
`endif

//IO
reg[7:0]dio;
wire IOWR,IORD;

assign IOWR = WIO;
assign IORD = RIO;

//UART: PORTS 0xE8 - DATA, 0xE9 - CONTROL/STATUS
wire tx_start,tx_bsy;
assign tx_start = (CPU_ADD[7:0] == 8'hE8)? ~IOWR : 1'b0;

//UART Tx
uart_tx(.clk(clk),.rst(CRST),.start(tx_start),.DIN(CPU_DO),.tx(UART_TX),.bsy(tx_bsy));

//Read IO
always@(negedge IORD)
	begin
		case(CPU_ADD[7:0])
			8'h06: dio <= {1'b1,KPB}; //Keyboard
			8'h05: dio <= {5'b11111,KPC[2:0]};
			8'h04: dio <= {7'b1111111,KPC[0]};
			default: dio <= 8'hFF;
		endcase
	end

assign IO_DO = dio;

`ifdef SRAM
	assign CPU_DI = (RM==0)? ER_D : ((RIO==0)? IO_DO : 8'h00);
`endif

`ifdef SDRAM
	assign CPU_DI = (~RM)? SDRAM_DO[7:0] : ((~RIO)? IO_DO : 8'h00);
`endif

//Write IO
reg[7:0]kpa = 8'hFF; //Порт линии сканирования клавиатуры
reg[7:0]pff = 8'h00; //Порт FF

always@(negedge IOWR or negedge CRST)
	begin
		if(!CRST)
			begin
				kpa <= 8'hFF;
				pff <= 8'h00;
			end
		else
			begin
				case(CPU_ADD[7:0])
					8'h07: kpa <= CPU_DO; //Keyboard
					8'hFF: pff <= CPU_DO;
					8'hFE: pff <= CPU_DO;
					8'hFD: pff <= CPU_DO;
					8'hFC: pff <= CPU_DO;
					default:;
				endcase
			end
	end

assign KPA = kpa;
assign PFF = pff;

`ifdef DEBUG
assign LED = CRST;

din7seg md7s(
.clk(clk),
.I0(CPU_ADD[3:0]),
.I1(CPU_ADD[7:4]),
.I2(CPU_ADD[11:8]),
.I3(CPU_ADD[15:12]),
`ifdef SRAM
	.I4(ER_D[3:0]),
	.I5(ER_D[7:4]),
`endif
`ifdef SDRAM
	.I4(SDRAM_DO[3:0]),
	.I5(SDRAM_DO[7:4]),
`endif
.I6(CPU_DO[3:0]),
.I7(CPU_DO[7:4]),
.SEG(SEG),
.RAZR(RAZR)
);
`endif

endmodule


module din7seg 
#(
 parameter razr_val = 8, //Количество разрядов  от 2 до 9 
 parameter in_clock = 50_000_000, //Входная частота
 parameter din_clock = razr_val*50, //Частота динамической индикации
 parameter clk_val = in_clock/din_clock/2-1, //Делитель частоты
 parameter reg_val = $clog2(clk_val)  //Разрядность делителя 
)
(
input wire clk,
input wire[3:0]I0,
input wire[3:0]I1,
input wire[3:0]I2,
input wire[3:0]I3,
input wire[3:0]I4,
input wire[3:0]I5,
input wire[3:0]I6,
input wire[3:0]I7,
input wire[3:0]I8,
output reg[7:0]SEG,
output reg[(razr_val - 1):0]RAZR
);


reg[3:0]O;
reg[3:0]C;
reg[(reg_val-1):0]DIV_CNT;
reg clock;
 
 
 always@(posedge clk)
	begin
		DIV_CNT <= DIV_CNT+1;
		if(DIV_CNT == clk_val)
			begin
				DIV_CNT <= 0;
				clock<=~clock;
			end
	end
 
 always@(posedge clock)
   begin 
	  C <= C+1'b1;
	  if(C==(razr_val-1)) C<=0;
	end
 
 always@(C)
  begin
   case(C)
	 4'b0000: begin O <= I0; RAZR <= ~9'b111111110; end
	 4'b0001: begin O <= I1; RAZR <= ~9'b111111101; end
	 4'b0010: begin O <= I2; RAZR <= ~9'b111111011; end
	 4'b0011: begin O <= I3; RAZR <= ~9'b111110111; end
	 4'b0100: begin O <= I4; RAZR <= ~9'b111101111; end
	 4'b0101: begin O <= I5; RAZR <= ~9'b111011111; end
	 4'b0110: begin O <= I6; RAZR <= ~9'b110111111; end
	 4'b0111: begin O <= I7; RAZR <= ~9'b101111111; end
	 4'b1000: begin O <= I8; RAZR <= ~9'b011111111; end
	 default: begin O <= 0;  RAZR <= ~9'b111111111; end 
	endcase
 end
 
 //DECODER
  always@(O)
  begin
   case(O)
     4'b0000: SEG <= 8'b00111111;//0
     4'b0001: SEG <= 8'b00000110;//1
     4'b0010: SEG <= 8'b01011011;//2
     4'b0011: SEG <= 8'b01001111;//3
     4'b0100: SEG <= 8'b01100110;//4
     4'b0101: SEG <= 8'b01101101;//5
     4'b0110: SEG <= 8'b01111101;//6
     4'b0111: SEG <= 8'b00000111;//7
     4'b1000: SEG <= 8'b01111111;//8
     4'b1001: SEG <= 8'b01101111;//9
     4'b1010: SEG <= 8'b01110111;//A
     4'b1011: SEG <= 8'b01111100;//B
     4'b1100: SEG <= 8'b00111001;//C
     4'b1101: SEG <= 8'b01011110;//D
     4'b1110: SEG <= 8'b01111001;//E
     4'b1111: SEG <= 8'b01110001;//F
	  
   endcase
  end
 
endmodule

