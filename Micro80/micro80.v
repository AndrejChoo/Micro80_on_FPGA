module micro80(
	input wire clk,
	input wire rst,
	//HDMI (использовать тип выводов LVDS_E3R
	output wire[2:0]tmds,
	output wire tmdsc,
	//SRAM
	output wire[18:0]ER_ADD,
	inout wire[7:0]ER_D,
	output wire ER_CS,
	output wire ER_OE,
	output wire ER_WE,
	output wire ER_BH,
	output wire ER_BL,
	//PS/2
	//input wire PS2_CLK,
	//input wire PS2_DAT,
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
	//UART
	output wire UART_TX,
	input wire UART_RX,
	//Debug
	output wire LED,
	input wire HOLD
);

//CPM
wire[7:0]PFF;

//Clocking
wire CLK2_5,CLK5,CLK10,CLK20,CLK64,CLK320;

//Для Xilinx необходимо сгенерировать свой блок PLL
main_pll mpl(.inclk0(clk),.c0(CLK20),.c1(CLK64),.c2(CLK320));

reg[5:0] div;
always@(posedge CLK20) div <= div + 1;

assign CLK2_5 = div[2];
assign CLK5 = div[1];
assign CLK10 = div[0];

//CPU
wire[15:0]CPU_ADD;
wire[7:0]CPU_DI,CPU_DO,IO_DO;
wire MREQ,IORQ;
wire CRST;
//I8080
wire RM,WM,RIO,WIO,DBIN,WO,HLDA,SYNC,F1,F2;

assign CRST = (rst & HOLD & ~PROG);
assign F1 = CLK2_5;
assign F2 = ~CLK2_5;

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
	.pin_sync(SYNC),
);

reg[7:0]i8080ctrl;
wire[7:0]CCTRL;

always@(posedge clk)
	begin
		if(F2 == 0 && SYNC == 1) i8080ctrl[7:0] <= CPU_DO[7:0];
	end

assign CCTRL = (HLDA == 0)? i8080ctrl : 8'b11111111;

assign RIO = (HLDA)? ~(DBIN & CCTRL[6]) : 1'bz;
assign WIO = (HLDA)? ~(CCTRL[4] & ~WO) : 1'bz; 
assign RM = (HLDA)? ~(DBIN & CCTRL[7]) : 1'bz;
assign WM = (HLDA)?  ~(~CCTRL[4] & ~WO) : 1'bz; 

//Video
videocontroller mvc(.pixclk(CLK64),.hclk(CLK320),.rst(rst),.tmds(tmds),.tmdsc(tmdsc),
						  .ADD(CPU_ADD),.DIN(CPU_DO),.WR(WM),.color(color));

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

//Programmer
wire PROG,PROGWE;
wire[18:0]PROGADD;
wire[7:0]PROGDO;

programmer mpg(.clk(clk),.rst(rst),.PROG(PROG),.SRAMADD(PROGADD),.SRAMDO(PROGDO),.SRAMWE(PROGWE),
					.SPI_CS(SPI_CS),.SPI_MOSI(MOSI),.SPI_MISO(MISO),.SPI_SCK(SCK));

//Keyboard
wire[7:0]KPA;
wire[6:0]KPB;
wire[2:0]KPC;

	//PS/2 клавиатура (работает нестабильно - залипают клавиши)
//keyboard mkb(.clk(clk),.rst(CRST),.clock(PS2_CLK),.dat(PS2_DAT),.PA(KPA), .PC(KPC),.PB(KPB));

//USB клавиатура через переходник на STM32F411CEU	
keyboard_usb  mkbu(.rst(CRST),.MOSI(KB_MOSI),.SCK(KB_SCK),.CS(KB_CS),.LATCH(KB_LATCH),.PA(KPA),
						 .PC(KPC),.PB(KPB),.LED(LED));


//SRAM
wire[7:0] ER_DI;
wire RAM_WE,MON_WE,CPM_WE;

assign MON_ADD = (start)? {3'b000,CPU_ADD[15:0]} : {8'b00011111,CPU_ADD[10:0]}; //
assign CPM_ADD = (CPU_ADD[15] == 1'b0)? {PFF[5:4],~PFF[2],PFF[3],~CPU_ADD[14:0]} : {3'b000,CPU_ADD[15:0]}; //PFF[0]
assign MON_WE = (CPU_ADD > 16'hF800)? 1'b1 : WM;
assign CPM_WE = (PFF[5:2] == 4'b0000 && CPU_ADD[15] == 0)? 1'b1 : WM;

assign ER_ADD[18:0] = (PROG)? PROGADD[18:0] : ((mode)? CPM_ADD : MON_ADD);
assign ER_D = (ER_WE == 0)? ER_DI : 8'bzzzzzzzz;
assign ER_DI = (PROG)? PROGDO : CPU_DO;
assign ER_WE = (PROG)? PROGWE : RAM_WE;
assign ER_OE = (PROG)? 1'b1 : 1'b0;
assign ER_CS = (PROG)? 1'b0 : (RM & WM);

assign RAM_WE = (mode)? CPM_WE : MON_WE;
assign ER_BH = 1'b1;
assign ER_BL = 1'b0;

//IO
reg[7:0]dio;
wire IOWR,IORD;

assign IOWR = WIO;
assign IORD = RIO;

//UART: PORTS 0xE8 - DATA, 0xE9 - CONTROL/STATUS
wire tx_start,tx_bsy;
assign tx_start = (CPU_ADD[7:0] == 8'hE8)? ~IOWR : 1'b0;

	//UART Tx (пока только Tx)
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
assign CPU_DI = (~RM)? ER_D : ((~RIO)? IO_DO : 8'h00);

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
					  
endmodule


