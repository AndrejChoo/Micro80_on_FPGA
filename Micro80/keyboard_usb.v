module keyboard_usb      
(
	input wire rst,
	//KB_SPI
	input wire MOSI,
	input wire SCK,
	input wire CS,
	input wire LATCH,
	//PC Bus
	input wire[7:0]PA, //SCAN ADDRESS PORT
	output wire[2:0]PC, //DOB BUTTON PORT: {SS,UST,RUS}
	output wire[6:0]PB, //KEY DATA PORT
	//Debug
	output wire LED
);

//SPI
reg[15:0]tdat,dat;
reg[3:0]scnt;

//Debug
reg[15:0] ld;

always@(negedge rst or posedge SCK)
	begin
		if(!rst)
			begin
				tdat <= 0;
			end
		else
			begin
				tdat[(15-scnt[3:0])] <= MOSI;
			end
	end
	
always@(posedge LATCH or negedge SCK)
	begin
		if(LATCH)
			begin
				scnt <= 0;
			end	
		else
			begin
				scnt <= scnt + 1;
			end	
	end

always@(posedge CS) dat <= tdat;

//Process data
reg rus = 1,ss = 1,us = 1;
reg[55:0]KR = 56'hFFFFFFFFFFFFFF;


always@(negedge LATCH or negedge rst)
	begin
		if(!rst)
			begin
				rus <= 1;
				ss <= 1;
				us <= 1;
				KR[55:0] <= 56'hFFFFFFFFFFFFFF;			
			end
		else
			begin
				if(dat[15:8] == 8'h02 || dat[15:8] == 8'h0D) //Shift
					begin
						case(dat[7:0])
							8'h80: KR[55] <= dat[9]; //SHIFT
							8'h83: KR[55] <= dat[9]; //SHIFT
						endcase
					end
				else if(dat[15:8] == 8'h04 || dat[15:8] == 8'h0B) //Control
					begin
						case(dat[7:0])
							8'h81: ss <= dat[10]; //CTRL
							8'h85: ss <= dat[10]; //CTRL
						endcase
					end
				else
					begin
						case(dat[7:0])
							8'h81: ss <= dat[8]; //CTRL
							8'h52: KR[51] <= dat[8]; //UP
							8'h4F: KR[49] <= dat[8]; //RIGHT
							8'h50: KR[50] <= dat[8]; //LEFT
							8'h51: KR[52] <= dat[8]; //DOWN
							8'h04: KR[17] <= dat[8]; //A
							8'h05: KR[18] <= dat[8]; //B
							8'h06: KR[19] <= dat[8]; //C
							8'h07: KR[20] <= dat[8]; //D
							8'h08: KR[21] <= dat[8]; //E
							8'h09: KR[22] <= dat[8]; //F
							8'h0A: KR[23] <= dat[8]; //G
							8'h0B: KR[24] <= dat[8]; //H
							8'h0C: KR[25] <= dat[8]; //I
							8'h0D: KR[26] <= dat[8]; //J
							8'h0E: KR[27] <= dat[8]; //K
							8'h0F: KR[28] <= dat[8]; //L
							8'h10: KR[29] <= dat[8]; //M
							8'h11: KR[30] <= dat[8]; //N
							8'h12: KR[31] <= dat[8]; //O
							8'h13: KR[32] <= dat[8]; //P
							8'h14: KR[33] <= dat[8]; //Q
							8'h15: KR[34] <= dat[8]; //R
							8'h16: KR[35] <= dat[8]; //S
							8'h17: KR[36] <= dat[8]; //T
							8'h18: KR[37] <= dat[8]; //U
							8'h19: KR[38] <= dat[8]; //V
							8'h1A: KR[39] <= dat[8]; //W
							8'h1B: KR[40] <= dat[8]; //X
							8'h1C: KR[41] <= dat[8]; //Y
							8'h1D: KR[42] <= dat[8]; //Z
							8'h27: KR[0] <= dat[8]; //0
							8'h1E: KR[1] <= dat[8]; //1
							8'h1F: KR[2] <= dat[8]; //2
							8'h20: KR[3] <= dat[8]; //3
							8'h21: KR[4] <= dat[8]; //4
							8'h22: KR[5] <= dat[8]; //5
							8'h23: KR[6] <= dat[8]; //6
							8'h24: KR[7] <= dat[8]; //7
							8'h25: KR[8] <= dat[8]; //8
							8'h26: KR[9] <= dat[8]; //9
							//NUM PAD
							8'h62: KR[0] <= dat[8]; //0
							8'h59: KR[1] <= dat[8]; //1
							8'h5A: KR[2] <= dat[8]; //2
							8'h5B: KR[3] <= dat[8]; //3
							8'h5C: KR[4] <= dat[8]; //4
							8'h5D: KR[5] <= dat[8]; //5
							8'h5E: KR[6] <= dat[8]; //6
							8'h5F: KR[7] <= dat[8]; //7
							8'h60: KR[8] <= dat[8]; //8
							8'h61: KR[9] <= dat[8]; //9

							8'h36: KR[12] <= dat[8]; //,
							8'h37: KR[14] <= dat[8]; //.
							8'h38: KR[15] <= dat[8]; //?/
							8'h33: KR[10] <= dat[8]; //;
							8'h45: us <= dat[10]; //F12
							8'h52: KR[16] <= dat[8]; //@					
							8'h2F: KR[43] <= dat[8]; //[
							8'h2E: KR[11] <= dat[8]; //+
							8'h39: KR[54] <= dat[8]; //CAPS LOCK
							8'h28: KR[53] <= dat[8]; //ENTER
							8'h58: KR[53] <= dat[8]; //ENTER
							8'h30: KR[45] <= dat[8]; //]
							8'h31: KR[44] <= dat[8]; //\
							8'h2D: KR[13] <= dat[8]; //-
							8'h56: KR[13] <= dat[8]; //-								
							8'h2A: rus <= dat[8]; //BKSPC	
							//Комбинации
							8'h2C: {KR[0],ss} <= {dat[8],dat[8]}; //SPACE
							8'h55: {KR[10],ss} <= {dat[8],dat[8]}; //*
							8'h57: {KR[11],ss} <= {dat[8],dat[8]}; //+
						endcase
					end
			end
	end


assign PB[0] = ((PA[0]|KR[0])&(PA[1]|KR[7])&(PA[2]|KR[14])&(PA[3]|KR[21])&
                (PA[4]|KR[28])&(PA[5]|KR[35])&(PA[6]|KR[42])&(PA[7]|KR[49]));
					 
assign PB[1] = ((PA[0]|KR[1])&(PA[1]|KR[8])&(PA[2]|KR[15])&(PA[3]|KR[22])&
                (PA[4]|KR[29])&(PA[5]|KR[36])&(PA[6]|KR[43])&(PA[7]|KR[50]));
					 
assign PB[2] = ((PA[0]|KR[2])&(PA[1]|KR[9])&(PA[2]|KR[16])&(PA[3]|KR[23])&
                (PA[4]|KR[30])&(PA[5]|KR[37])&(PA[6]|KR[44])&(PA[7]|KR[51]));
					 
assign PB[3] = ((PA[0]|KR[3])&(PA[1]|KR[10])&(PA[2]|KR[17])&(PA[3]|KR[24])&
                (PA[4]|KR[31])&(PA[5]|KR[38])&(PA[6]|KR[45])&(PA[7]|KR[52]));
					 
assign PB[4] = ((PA[0]|KR[4])&(PA[1]|KR[11])&(PA[2]|KR[18])&(PA[3]|KR[25])&
                (PA[4]|KR[32])&(PA[5]|KR[39])&(PA[6]|KR[46])&(PA[7]|KR[53]));
					 
assign PB[5] = ((PA[0]|KR[5])&(PA[1]|KR[12])&(PA[2]|KR[19])&(PA[3]|KR[26])&
                (PA[4]|KR[33])&(PA[5]|KR[40])&(PA[6]|KR[47])&(PA[7]|KR[54]));
					 
assign PB[6] = ((PA[0]|KR[6])&(PA[1]|KR[13])&(PA[2]|KR[20])&(PA[3]|KR[27])&
                (PA[4]|KR[34])&(PA[5]|KR[41])&(PA[6]|KR[48])&(PA[7]|KR[55]));
				 
//PC[2:0] = {SS,UST,RUS}
assign PC[0] = rus;
assign PC[1] = us;
assign PC[2] = ss;

always@(negedge MOSI) ld <= ld + 1;

assign LED = (ld > 16)? 0 : 1;

endmodule
