module videocontroller(
	input wire pixclk,
	input wire hclk,
	input wire rst,
	//HDMI
	output wire[2:0]tmdsp,
    output wire[2:0]tmdsn,
	output wire tmdscp,
	output wire tmdscn,
	//System bus
	input wire[7:0]DIN,
	input wire[15:0]ADD,
	input wire WR,
    input wire color
);

wire[7:0]R,G,B;
wire[10:0]HCNT,VCNT;
wire VISIBLE;

hdmi mhd(
    .pixclk(pixclk),
    .clk_TMDS(hclk),
    .n_rst(rst),
    .TMDSp(tmdsp),
    .TMDSn(tmdsn),
    .TMDSp_clock(tmdscp),
	.TMDSn_clock(tmdscn),
    .red(R),
    .green(G),
    .blue(B),
    .visible(VISIBLE),
    .HCNT(HCNT),
    .VCNT(VCNT)
    );

wire[10:0]VR_RADD;
wire[7:0]VR_DO;
wire VR_RCLK,VR_WCLK,VR_WREN;		

//Память номеров символов

vram mvr(
    .dout(VR_DO),
    .clkb(VR_RCLK),
    .ceb(1'b1),
    .resetb(1'b0),
    .adb(VR_RADD),
    .oce(1'b1),
    .clka(VR_WCLK),
    .cea(VR_WREN),
    .reseta(resetb),
    .din(DIN),
    .ada(ADD[10:0])
    );

wire[10:0]AR_RADD;
wire[7:0]AR_DO;
wire AR_RCLK,AR_VCLK,AR_WREN;	

//Память атрибутов

vram avr(
    .dout(AR_DO),
    .clkb(AR_RCLK),
    .ceb(1'b1),
    .resetb(1'b0),
    .adb(AR_RADD),
    .oce(1'b1),
    .clka(AR_WCLK),
    .cea(AR_WREN),
    .reseta(resetb),
    .din(DIN),
    .ada(ADD[10:0])
    );

wire[11:0]ZR_ADD;
wire[7:0]ZR_DAT;
wire ZR_CLK;

//ROM знакогенератора
zrom zng(
    .dout(ZR_DAT),
    .clk(ZR_CLK),
    .oce(1'b1),
    .ce(1'b1),
    .reset(1'b0),
    .ad(ZR_ADD)
    );
		
//----------------------------Resolution 768x512 with scandoubler-----------------------------
wire BORDER,PREPARE;
wire[7:0]Rb,Gb,Bb,Rr,Gr,Br;
wire[10:0]NHCNT,NVCNT;
wire[10:0]ZNAKOMESTO;

assign BORDER = (VCNT >= 63 && VCNT < 704 && HCNT > 161 && HCNT < 1180)? 1'b1 : 1'b0;

assign NHCNT = HCNT - 146;
assign NVCNT = VCNT - 63;
assign ZNAKOMESTO = (NHCNT[10:4]) + (((NVCNT[10:1])/10) * 64) - 64; // -65 вычислено опытным путём

//Гашение
assign R = (VISIBLE&BORDER)? Rb : 8'h00;	
assign G = (VISIBLE&BORDER)? Gb : 8'h00;	
assign B = (VISIBLE&BORDER)? Bb : 8'h00;
/*
//Цвет бордюра
assign Rr = (BORDER)? Rb : 8'h00;	
assign Gr = (BORDER)? Gb : 8'h00;	
assign Br = (BORDER)? Bb : 8'h00;
*/

//Автомат чтения данных знакоместа и шрифта
reg[7:0]tzd,zd;
reg[7:0]zad,atr,tatr;
reg zclk,vclk;

//Debug information
reg[7:0]digs[0:21];

always@(negedge pixclk or negedge rst)
	begin
		if(!rst)
			begin	
				zd <= 0;
				atr <= 0;
				tzd <= 0;
				tatr <= 0;
				
				zclk <= 0;
				vclk <= 0;
			end
		else
			begin
				case(NHCNT[3:0])
					1: vclk <= 1'b1;
					4: vclk <= 1'b0;
					6: 
						begin
							zad <= VR_DO;
							tatr <= AR_DO;
						end
					/*
					7:
						begin
							if(tatr[7]) zad <= 8'h5F;
						end
					*/
					8: zclk <= 1'b1;
					11: zclk <= 1'b0;
					14: 
						begin
							if((tatr[7] == 1) && ((NVCNT[10:1]) % 10)==9) tzd[7:0] <= 8'hFF; 
							else tzd[7:0] <= ZR_DAT[7:0];
						end
					0: 
						begin
							zd <= tzd;
							atr <= tatr;
						end
					
				endcase
			end
	end

assign VR_RADD = ZNAKOMESTO;
assign VR_RCLK = ~vclk;
assign AR_RADD = ZNAKOMESTO;
assign AR_RCLK = ~vclk;
assign ZR_ADD = (zad * 16) + ((NVCNT[10:1]) % 10);//vcnt; //???
assign ZR_CLK = ~zclk;

//Формируем изображение
wire[7:0]Rp,Gp,Bp,Ri,Gi,Bi,Bri;

assign Bri = (atr[3])? 8'h3F : 8'h00;

assign Rp = (atr[6])? 8'hFF : 8'h00;
assign Gp = (atr[5])? 8'hFF : 8'h00;
assign Bp = (atr[4])? 8'hFF : 8'h00;

assign Ri = (atr[2])? (8'hC0 | Bri) : (8'h00 | Bri);
assign Gi = (atr[1])? (8'hC0 | Bri) : (8'h00 | Bri);
assign Bi = (atr[0])? (8'hC0 | Bri) : (8'h00 | Bri);


assign Rb = (color)? ((zd[(7-(NHCNT[3:1]))])? Ri : Rp) : 8'h00;
assign Gb = (color)? ((zd[(7-(NHCNT[3:1]))])? Gi : Gp) : ((zd[(7-(NHCNT[3:1]))])? 8'hC0 : 8'h00);
assign Bb = (color)? ((zd[(7-(NHCNT[3:1]))])? Bi : Bp) : ((zd[(7-(NHCNT[3:1]))])? 8'h0B : 8'h00);

/*
assign Rb = 8'h00;
assign Gb = (zd[(7-(NHCNT[3:1]))])? 8'hC0 : 8'h00;
assign Bb = (zd[(7-(NHCNT[3:1]))])? 8'h0B : 8'h00;
*/

//Запись
assign VR_WREN = (ADD >= 16'hE800 && ADD < 16'hF000)? 1'b1 : 1'b0;
assign VR_WCLK = WR | pixclk;	
assign AR_WREN = (ADD >= 16'hE000 && ADD < 16'hE800)? 1'b1 : 1'b0;
assign AR_WCLK = WR | pixclk;

/*
//I8080
assign VR_WREN = (ADD >= 16'hE800 && ADD < 16'hF000)? 1'b1 : 1'b0;
assign VR_WCLK = ~WR | pixclk;	
assign AR_WREN = (ADD >= 16'hE000 && ADD < 16'hE800)? 1'b1 : 1'b0;
assign AR_WCLK = ~WR | pixclk;
*/
endmodule
