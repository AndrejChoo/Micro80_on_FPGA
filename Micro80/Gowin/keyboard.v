module keyboard      
(
	input wire clk,
	input wire rst,
	//PS/2
	input wire clock,
	input wire dat,
	//PC Bus
	input wire[7:0]PA, //SCAN ADDRESS PORT
	output wire[2:0]PC, //DOB BUTTON PORT: {SS,UST,RUS}
	output wire[6:0]PB //KEY DATA PORT
);

`define KEMPSTON
`define KOMBINATIONS

	
	reg read;				//this is 1 if still waits to receive more bits 
	reg [11:0] count_reading;		//this is used to detect how much time passed since it received the previous codeword
	reg PREVIOUS_STATE;			//used to check the previous state of the keyboard clock signal to know if it changed
	reg scan_err;				//this becomes one if an error was received somewhere in the packet
	reg [10:0] scan_code;			//this stores 11 received bits
	reg [7:0] CODEWORD;			//this stores only the DATA codeword
	reg TRIG_ARR;				//this is triggered when full 11 bits are received
	reg [3:0]COUNT;				//tells how many bits were received until now (from 0 to 11)
	reg TRIGGER = 0;			//This acts as a 250 times slower than the board clock. 
	reg [7:0]DOWNCOUNTER = 0;		//This is used together with TRIGGER - look the code

	//Set initial values
	initial begin
		PREVIOUS_STATE = 1;		
		scan_err = 0;		
		scan_code = 0;
		COUNT = 0;			
		CODEWORD = 0;

		read = 0;
		count_reading = 0;
	end

	always @(posedge clk) begin				//This reduces the frequency 250 times
		if (DOWNCOUNTER < 249) begin			//and uses variable TRIGGER as the new board clock 
			DOWNCOUNTER <= DOWNCOUNTER + 1;
			TRIGGER <= 0;
		end
		else begin
			DOWNCOUNTER <= 0;
			TRIGGER <= 1;
		end
	end
	
	always @(posedge clk) begin	
		if (TRIGGER) begin
			if (read)				//if it still waits to read full packet of 11 bits, then (read == 1)
				count_reading <= count_reading + 1;	//and it counts up this variable
			else 						//and later if check to see how big this value is.
				count_reading <= 0;			//if it is too big, then it resets the received data
		end
	end


	always @(posedge clk) begin		
	if (TRIGGER) begin						//If the down counter (clk/250) is ready
		if (clock != PREVIOUS_STATE) begin			//if the state of Clock pin changed from previous state
			if (!clock) begin				//and if the keyboard clock is at falling edge
				read <= 1;				//mark down that it is still reading for the next bit
				scan_err <= 0;				//no errors
				scan_code[10:0] <= {dat, scan_code[10:1]};	//add up the data received by shifting bits and adding one new bit
				COUNT <= COUNT + 1;			//
			end
		end
		else if (COUNT == 11) begin				//if it already received 11 bits
			COUNT <= 0;
			read <= 0;					//mark down that reading stopped
			TRIG_ARR <= 1;					//trigger out that the full pack of 11bits was received
			//calculate scan_err using parity bit
			if (!scan_code[10] || scan_code[0] || !(scan_code[1]^scan_code[2]^scan_code[3]^scan_code[4]
				^scan_code[5]^scan_code[6]^scan_code[7]^scan_code[8]
				^scan_code[9]))
				scan_err <= 1;
			else 
				scan_err <= 0;
		end	
		else  begin						//if it yet not received full pack of 11 bits
			TRIG_ARR <= 0;					//tell that the packet of 11bits was not received yet
			if (COUNT < 11 && count_reading >= 4000) begin	//and if after a certain time no more bits were received, then
				COUNT <= 0;				//reset the number of bits received
				read <= 0;				//and wait for the next packet
			end
		end
	PREVIOUS_STATE <= clock;					//mark down the previous state of the keyboard clock
	end
	end


	always @(posedge clk) begin
		if (TRIGGER) begin					//if the 250 times slower than board clock triggers
			if (TRIG_ARR) begin				//and if a full packet of 11 bits was received
				if (scan_err) begin			//BUT if the packet was NOT OK
					CODEWORD <= 8'd0;		//then reset the codeword register
				end
				else begin
					CODEWORD <= scan_code[8:1];	//else drop down the unnecessary  bits and transport the 7 DATA bits to CODEWORD reg
				end				//notice, that the codeword is also reversed! This is because the first bit to received
			end					//is supposed to be the last bit in the codeword…
			else CODEWORD <= 8'd0;				//not a full packet received, thus reset codeword
		end
		else CODEWORD <= 8'd0;					//no clock trigger, no data…
	end
	
wire stb;
assign stb = TRIG_ARR;

//Конвертер сканкодов в кнопки ZX

reg pr,joy,rus = 1,ss = 1,us = 1;
reg[55:0]KR = 56'hFFFFFFFFFFFFFF;
`ifdef KEMPSTON	
reg[2:0]pc;
`endif

reg reset;
reg nmi;

always@(posedge stb or negedge rst)
begin
	if(!rst)
		begin
			pr <= 0;
			joy <= 0;
			rus <= 1;
			ss <= 1;
			us <= 1;
			KR[55:0] <= 56'hFFFFFFFFFFFFFF;
		end
	else
		begin
			if(scan_code[8:1] == 8'hF0) pr <= 1'b1;
			else if(scan_code[8:1] == 8'hE0) joy <= 1'b1; 
			else
				begin
					if(joy) //Клавиши c 0xE0
						begin
							case(scan_code[8:1])
								8'h14: ss <= pr; //CTRL
								8'h75: KR[51] <= pr; //UP
								8'h74: KR[49] <= pr; //RIGHT
								8'h6B: KR[50] <= pr; //LEFT
								8'h72: KR[52] <= pr; //DOWN
								default:;
							endcase
							joy <= 0;
							pr <= 0;
						end
					else	//Обычные клавиши
						begin
							case(scan_code[8:1])
								8'h1C: KR[17] <= pr; //A
								8'h32: KR[18] <= pr; //B
								8'h21: KR[19] <= pr; //C
								8'h23: KR[20] <= pr; //D
								8'h24: KR[21] <= pr; //E
								8'h2B: KR[22] <= pr; //F
								8'h34: KR[23] <= pr; //G
								8'h33: KR[24] <= pr; //H
								8'h43: KR[25] <= pr; //I
								8'h3B: KR[26] <= pr; //J
								8'h42: KR[27] <= pr; //K
								8'h4B: KR[28] <= pr; //L
								8'h3A: KR[29] <= pr; //M
								8'h31: KR[30] <= pr; //N
								8'h44: KR[31] <= pr; //O
								8'h4D: KR[32] <= pr; //P
								8'h15: KR[33] <= pr; //Q
								8'h2D: KR[34] <= pr; //R
								8'h1B: KR[35] <= pr; //S
								8'h2C: KR[36] <= pr; //T
								8'h3C: KR[37] <= pr; //U
								8'h2A: KR[38] <= pr; //V
								8'h1D: KR[39] <= pr; //W
								8'h22: KR[40] <= pr; //X
								8'h35: KR[41] <= pr; //Y
								8'h1A: KR[42] <= pr; //Z
								8'h45: KR[0] <= pr; //0
								8'h16: KR[1] <= pr; //1
								8'h1E: KR[2] <= pr; //2
								8'h26: KR[3] <= pr; //3
								8'h25: KR[4] <= pr; //4
								8'h2E: KR[5] <= pr; //5
								8'h36: KR[6] <= pr; //6
								8'h3D: KR[7] <= pr; //7
								8'h3E: KR[8] <= pr; //8
								8'h46: KR[9] <= pr; //9
								//NUM PAD
								8'h70: KR[0] <= pr; //0
								8'h69: KR[1] <= pr; //1
								8'h72: KR[2] <= pr; //2
								8'h7A: KR[3] <= pr; //3
								8'h6B: KR[4] <= pr; //4
								8'h73: KR[5] <= pr; //5
								8'h74: KR[6] <= pr; //6
								8'h6C: KR[7] <= pr; //7
								8'h75: KR[8] <= pr; //8
								8'h7D: KR[9] <= pr; //9
								//
								8'h41: KR[12] <= pr; //,
								8'h49: KR[14] <= pr; //.
								8'h4A: KR[15] <= pr; //?/
								8'h4C: KR[10] <= pr; //;
								8'h14: ss <= pr; //CTRL
								8'h07: us <= pr; //F12
								8'h52: KR[16] <= pr; //@					
								8'h54: KR[43] <= pr; //[
								8'h55: KR[11] <= pr; //+
								8'h58: KR[54] <= pr; //CAPS LOCK
								8'h5A: KR[53] <= pr; //ENTER
								8'h5B: KR[45] <= pr; //]
								8'h5D: KR[44] <= pr; //\
								8'h4E: KR[13] <= pr; //-
								8'h7B: KR[13] <= pr; //-								
								8'h66: rus <= pr; //BKSPC
								8'h12: KR[55] <= pr; //SHIFT
								8'h59: KR[55] <= pr; //SHIFT
`ifdef KOMBINATIONS
								//Комбинации
								8'h29: {KR[0],ss} <= {pr,pr}; //SPACE
								8'h7C: {KR[10],ss} <= {pr,pr}; //*
								8'h79: {KR[11],ss} <= {pr,pr}; //*
								//8'h66: {KR[0],KR[20]} <= {pr,pr}; //, BKSPC SHIFT+0
`endif

`ifdef KEMPSTON								
								//8'h79: kempston[4] <= ~pr; //FIRE (NUM ENTER)
								//8'h75: kempston[3] <= ~pr; //UP
								//8'h72: kempston[2] <= ~pr; //DOWN
								//8'h6B: kempston[1] <= ~pr; //LEFT
								//8'h74: kempston[0] <= ~pr; //RIGHT
`endif	
								//8'h05: reset <= ~pr; //Reset on F1
								//8'h07: nmi <= ~pr; //NMI on F12
								default:;
							endcase
							pr <= 0;	
						end
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


endmodule

