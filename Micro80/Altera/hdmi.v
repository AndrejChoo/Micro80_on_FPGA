/*	Разрешение 1024x768х60Hz требует частоты пиксельклока 65Mhz и вывода сигналов линий tmds на частоте 650Mhz, 
	но так как моя Altera Cyclone IV умеет только до 640Mhz (точнее до 640Mbit/s), то я уменьшил пиксельклок на 10 Mhz.
	Мой 2К монитор без проблем переварил такие ухищрения.
*/
module hdmi(
	input pixclk,  // 64MHz
	input clk_TMDS, //x5 CLK 
	input n_rst,
	output [2:0] TMDSp, //TMDSn,
	output TMDSp_clock,//, TMDSn_clock
	input wire [7:0] red,
	input wire [7:0] blue,
	input wire [7:0] green,
	output wire[10:0]HCNT,
	output wire[10:0]VCNT,
	output wire visible,
	output wire vs
);

////////////////////////////////////////////////////////////////////////
reg [10:0] CounterX, CounterY;
reg hSync, vSync, DrawArea;
always @(posedge pixclk or negedge n_rst) 
	begin
		if(!n_rst) DrawArea <= 0;
		else DrawArea <= (CounterX>159) && (CounterX<1184) && (CounterY>28) && (CounterY<797);
	end

always @(posedge pixclk or negedge n_rst) 
	begin
		if(!n_rst) CounterX <= 0;
		else CounterX <= (CounterX==1343) ? 0 : CounterX+1;
	end
always @(posedge pixclk or negedge n_rst) 
	begin
		if(!n_rst) CounterY <= 0;
		else 
			begin
				if(CounterX==1343) CounterY <= (CounterY==805) ? 0 : CounterY+1;
			end
	end

always @(posedge pixclk) hSync <= (CounterX>=1208);
always @(posedge pixclk) vSync <= (CounterY>=800);

assign vs = vSync;
assign visible = DrawArea;
assign HCNT = CounterX;
assign VCNT = CounterY;

////////////////////////////////////////////////////////////////////////
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
TMDS_encoder encode_R(.clk(pixclk), .VD(red  ), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(pixclk), .VD(green), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_green));
TMDS_encoder encode_B(.clk(pixclk), .VD(blue ), .CD({vSync,hSync}), .VDE(DrawArea), .TMDS(TMDS_blue));

////////////////////////////////////////////////////////////////////////
wire DCM_TMDS_CLKFX;  // 25MHz x 10 = 250MHz
assign DCM_TMDS_CLKFX = clk_TMDS;

////////////////////////////////////////////////////////////////////////
reg [2:0] TMDS_mod5=0;  // modulus 10 counter
reg [4:0] TMDSp_shift_red=0, TMDSp_shift_green=0, TMDSp_shift_blue=0;
reg [4:0] TMDSn_shift_red=0, TMDSn_shift_green=0, TMDSn_shift_blue=0;
reg TMDS_shift_load=0;

always @(posedge clk_TMDS) TMDS_shift_load <= (TMDS_mod5==4'd4);

always @(posedge clk_TMDS)
begin
	TMDSp_shift_red   <= TMDS_shift_load ? {TMDS_red[8],TMDS_red[6],TMDS_red[4],TMDS_red[2],TMDS_red[0]} : TMDSp_shift_red [4:1];
	TMDSn_shift_red   <= TMDS_shift_load ? {TMDS_red[9],TMDS_red[7],TMDS_red[5],TMDS_red[3],TMDS_red[1]} : TMDSn_shift_red [4:1];
	TMDSp_shift_green   <= TMDS_shift_load ? {TMDS_green[8],TMDS_green[6],TMDS_green[4],TMDS_green[2],TMDS_green[0]} : TMDSp_shift_green [4:1];
	TMDSn_shift_green   <= TMDS_shift_load ? {TMDS_green[9],TMDS_green[7],TMDS_green[5],TMDS_green[3],TMDS_green[1]} : TMDSn_shift_green [4:1];
	TMDSp_shift_blue   <= TMDS_shift_load ? {TMDS_blue[8],TMDS_blue[6],TMDS_blue[4],TMDS_blue[2],TMDS_blue[0]} : TMDSp_shift_blue [4:1];
	TMDSn_shift_blue   <= TMDS_shift_load ? {TMDS_blue[9],TMDS_blue[7],TMDS_blue[5],TMDS_blue[3],TMDS_blue[1]} : TMDSn_shift_blue [4:1];	
	TMDS_mod5 <= (TMDS_mod5==3'd4) ? 3'd0 : TMDS_mod5+3'd1;
end

ALTDDIO adr(
	.datain_h(TMDSp_shift_red  [0]),
	.datain_l(TMDSn_shift_red  [0]),
	.outclock(clk_TMDS),
	.dataout(TMDSp[2])
	);
	
ALTDDIO adg(
	.datain_h(TMDSp_shift_green  [0]),
	.datain_l(TMDSn_shift_green  [0]),
	.outclock(clk_TMDS),
	.dataout(TMDSp[1])
	);
	
ALTDDIO adb(
	.datain_h(TMDSp_shift_blue  [0]),
	.datain_l(TMDSn_shift_blue  [0]),
	.outclock(clk_TMDS),
	.dataout(TMDSp[0])
	);

assign TMDSp_clock = pixclk;

endmodule


////////////////////////////////////////////////////////////////////////
module TMDS_encoder(
	input clk,
	input [7:0] VD,  // video data (red, green or blue)
	input [1:0] CD,  // control data
	input VDE,  // video data enable, to choose between CD (when VDE=0) and VD (when VDE=1)
	output reg [9:0] TMDS = 0
);

wire [3:0] Nb1s = VD[0] + VD[1] + VD[2] + VD[3] + VD[4] + VD[5] + VD[6] + VD[7];
wire XNOR = (Nb1s>4'd4) || (Nb1s==4'd4 && VD[0]==1'b0);
wire [8:0] q_m = {~XNOR, q_m[6:0] ^ VD[7:1] ^ {7{XNOR}}, VD[0]};

reg [3:0] balance_acc = 0;
wire [3:0] balance = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7] - 4'd4;
wire balance_sign_eq = (balance[3] == balance_acc[3]);
wire invert_q_m = (balance==0 || balance_acc==0) ? ~q_m[8] : balance_sign_eq;
wire [3:0] balance_acc_inc = balance - ({q_m[8] ^ ~balance_sign_eq} & ~(balance==0 || balance_acc==0));
wire [3:0] balance_acc_new = invert_q_m ? balance_acc-balance_acc_inc : balance_acc+balance_acc_inc;
wire [9:0] TMDS_data = {invert_q_m, q_m[8], q_m[7:0] ^ {8{invert_q_m}}};
wire [9:0] TMDS_code = CD[1] ? (CD[0] ? 10'b1010101011 : 10'b0101010100) : (CD[0] ? 10'b0010101011 : 10'b1101010100);

always @(posedge clk) TMDS <= VDE ? TMDS_data : TMDS_code;
always @(posedge clk) balance_acc <= VDE ? balance_acc_new : 4'h0;
endmodule


