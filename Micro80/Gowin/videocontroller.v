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
wire[9:0]HCNT,VCNT;
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
		
//----------------------------Resolution 512x320 with scandoubler-----------------------------
wire BORDER;
wire[7:0]Rb,Gb,Bb;
wire[10:0]NHCNT,NVCNT;
wire[10:0]ZNAKOMESTO;

assign BORDER = (HCNT >= 63 && HCNT < 575 && VCNT >= 79 && VCNT < 399)? 1'b1 : 1'b0;

assign NHCNT = HCNT - 55;
assign NVCNT = VCNT - 69;
assign ZNAKOMESTO = (NHCNT[10:3]) + ((NVCNT/10) * 64) - 64; // -65 вычислено опытным путём

//Автомат чтения данных знакоместа и шрифта
reg[7:0]tzd,zd,zad,tatr,atr;
reg zclk,vclk;

//Debug
reg[6:0]digs[0:15];

initial
    begin
        digs[0] = "0";
        digs[1] = "1";
        digs[2] = "2";
        digs[3] = "3";
        digs[4] = "4";
        digs[5] = "5";
        digs[6] = "6";
        digs[7] = "7";
        digs[8] = "8";
        digs[9] = "9";
        digs[10] = "a";
        digs[11] = "b";
        digs[12] = "c";
        digs[13] = "d";
        digs[14] = "e";
        digs[15] = "f";
    end

always@(negedge pixclk or negedge rst)
	begin
		if(!rst)
			begin
				tzd <= 0;
                zad <= 0;
                tatr <= 0;
				atr <= 0;
				zclk <= 0;
				vclk <= 0;
			end
		else
			begin
				case(NHCNT[2:0])
					1: vclk <= 1'b1;
					2: vclk <= 1'b0;
					3: 
						begin
							zad <= VR_DO;
							tatr <= AR_DO;
						end
					4:
						begin
							//if(atr[7]) zad <= 8'h5F;
                            case(ZNAKOMESTO)
                                //MEM DO
                                1912: zad <= "M";
                                1913: zad <= "E";
                                1914: zad <= "M";
                                1915: zad <= "D";
                                1916: zad <= ":";
                                1917: zad <= digs[(DIN[7:4])];
                                1918: zad <= digs[(DIN[3:0])];
                                //ADD
                                2039: zad <= "A";
                                2040: zad <= "D";
                                2041: zad <= "D";
                                2042: zad <= ":";
                                2043: zad <= digs[(ADD[15:12])];
                                2044: zad <= digs[(ADD[11:8])];
                                2045: zad <= digs[(ADD[7:4])];
                                2046: zad <= digs[(ADD[3:0])];
                                default: ;
                            endcase
						end
					5: zclk <= 1'b1;
					6: zclk <= 1'b0;
					7: 
						begin
							tzd[7:0] <= ZR_DAT[7:0];
							atr[7:0] <= AR_DO[7:0];
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
assign VR_RCLK = vclk;
assign AR_RADD = ZNAKOMESTO;
assign AR_RCLK = vclk;
assign ZR_ADD = (zad * 16) + (NVCNT % 10);//vcnt; //???
assign ZR_CLK = zclk;

	
//Формируем изображение
wire[7:0]Rp,Gp,Bp,Ri,Gi,Bi,Bri;

//Гашение
assign R = (VISIBLE&BORDER)? Rb : 8'h00;	
assign G = (VISIBLE&BORDER)? Gb : 8'h00;	
assign B = (VISIBLE&BORDER)? Bb : 8'h00;

assign Bri = (atr[3])? 8'h3F : 8'h00;

assign Rp = (atr[6])? 8'hFF : 8'h00;
assign Gp = (atr[5])? 8'hFF : 8'h00;
assign Bp = (atr[4])? 8'hFF : 8'h00;

assign Ri = (atr[2])? (8'hC0 | Bri) : (8'h00 | Bri);
assign Gi = (atr[1])? (8'hC0 | Bri) : (8'h00 | Bri);
assign Bi = (atr[0])? (8'hC0 | Bri) : (8'h00 | Bri);


assign Rb = (color)? ((zd[(7-(NHCNT[2:0]))])? Ri : Rp) : 8'h00;
assign Gb = (color)? ((zd[(7-(NHCNT[2:0]))])? Gi : Gp) : ((zd[(7-(NHCNT[2:0]))])? 8'hC0 : 8'h00);
assign Bb = (color)? ((zd[(7-(NHCNT[2:0]))])? Bi : Bp) : ((zd[(7-(NHCNT[2:0]))])? 8'h0B : 8'h00);


//Запись
assign VR_WREN = (ADD >= 16'hE800 && ADD < 16'hF000 && WR == 0)? 1'b1 : 1'b0;
assign VR_WCLK = pixclk;	
assign AR_WREN = (ADD >= 16'hE000 && ADD < 16'hE800 && WR == 0)? 1'b1 : 1'b0;
assign AR_WCLK = pixclk;

endmodule
