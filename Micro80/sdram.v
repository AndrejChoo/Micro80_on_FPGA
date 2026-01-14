module sdram(
	input wire clk,
	input wire rst,
	//RW Agent
	input wire wr,
	input wire rd,
	output wire rdy,
	output wire SDWAIT,
	input wire[23:0]ADD,
	input wire[15:0]DI,
	output wire[15:0]DO,	
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
	inout wire[15:0] SDRAM_DQ
);

//Задержки
localparam TRCD = 2;
localparam CL = 2;
localparam RBURST = 1;
localparam SDRAMFREQ = 96000000; //MHz
localparam RFSHDEL = SDRAMFREQ / 1000 * 64; // 64msec

//Commands: CS-RAS-CAS-WE
localparam[3:0] INHIBIT = 4'b1111;
localparam[3:0] NOP = 4'b0111;
localparam[3:0] BSTOP = 4'b0110;
localparam[3:0] READ = 4'b0101;
localparam[3:0] WRITE = 4'b0100;
localparam[3:0] ACTIVE = 4'b0011;
localparam[3:0] PRECHARGE = 4'b0010;
localparam[3:0] AUTOREFRESH = 4'b0001;
localparam[3:0] SETUP = 4'b0000;

//
wire[15:0] DIN, DOUT;

//Registers
reg[12:0]sadd;  //Регистр адреса
reg[3:0]opcode; //Регистр опкодов
reg[1:0]bank;   //Регистр банка
reg[22:0]count; //Счётчик задержек
reg cke;			 //Регистр состояния CKE
reg[15:0]sdo;    //Регистр данных для чтения
reg[15:0]tdat;   //Регистр данных на запись
reg[23:0]tadd;   //Регистр адреса для записи
reg trw;			  //Регистр хранения режима R/W
reg[22:0]rfshcnt;//Регистр таймера перезарядки

reg[6:0]state;
reg bsy = 1;
reg sdwait;

//Соединения
assign SDRAM_DQM[1:0] = 2'b00;
assign SDRAM_BS[1:0] = bank[1:0];
assign SDRAM_ADD[12:0] = sadd[12:0];
assign SDRAM_CKE = cke;
assign SDRAM_CLK = clk;
assign SDRAM_CS = opcode[3];
assign SDRAM_RAS = opcode[2];
assign SDRAM_CAS = opcode[1];
assign SDRAM_WE = opcode[0];
assign DO[15:0] = sdo[15:0];

assign SDRAM_DQ[15:0] = (trw)? DOUT : 16'bzzzz_zzzz_zzzz_zzzz;
assign DIN[15:0] = (trw)? 16'hFFFF : SDRAM_DQ[15:0];
assign DOUT[15:0] = tdat[15:0];


//Main state machine
always@(negedge clk or negedge rst)
begin
	if(!rst)
		begin
			state <= 0;
			bsy <= 1;
			sdwait <= 0;
			sadd <= 0;
			opcode <= INHIBIT;
			bank <= 0;
			count <= 0;
			cke <= 0;
			rfshcnt <= 0;
			//Запись
			trw <= 0;
			tadd <= 0;
		end
	else
		begin
			if(count > 0) count <= count - 1; //Декрементируем счётчик, если он не пустой
			if(rfshcnt > 0) rfshcnt <= rfshcnt - 1;
			//Состояния
			case(state)
				0: //Начало инициализации
					begin
						bsy <= 1;
						cke <= 0;
						opcode <= INHIBIT;
						bank <= 0;
						sadd <= 0;
						count <= 10000; //Ждём 100 uS для стабилизации состояния SDRAM
						state <= 1;
					end
				1: //
					begin
						if(count == 5000) cke <= 1;
						if(count == 0) state <= 2;
					end	
				2: //Выдать PRECHARGE ALL
					begin
						opcode <= PRECHARGE;
						bank <= 0;
						sadd[10] <= 1;
						count <= TRCD;
						state <= 3;
					end	
				3: //
					begin
						opcode <= NOP;
						sadd[10] <= 0;
						if(count == 0) state <= 4;
					end
				4: //Выдать AUTOREFRESH
					begin
						opcode <= AUTOREFRESH;
						//cke <= 1; //??????????????????????
						count <= 6400000;
						state <= 5;
					end
				5: //
					begin
						opcode <= NOP;
						//cke <= 0;
						if(count == 0) state <= 6;
					end	
				6: //Выдать AUTOREFRESH
					begin
						opcode <= AUTOREFRESH;
						count <= 6400000;
						state <= 7;
					end
				7: //
					begin
						opcode <= NOP;
						if(count == 0) state <= 8;
					end	
				8: //Запрограммировать регистр настроек
					begin
						opcode <= SETUP;
						sadd[2:0] <= 3'b000; //Burst lenght: 000 - 1, 001 - 2, 010 - 4, 011 - 8, 111 - full page
						sadd[3] <= 1'b0;			//Addressing mode: 0 - secuential, 1 - interleave
						sadd[6:4] <= CL; 			//CAS Latency: 010 - 2, 011 - 3
						sadd[8:7] <= 2'b00;  //Reserved
						sadd[9] <= 1'b1;		//Write mode: 0 - burst read and write, 1 - burst read and single write
						sadd[12:10] <= 3'b000; //Reserved
						bank <= 0;
						count <= TRCD;
						state <= 9;
					end
				9: //
					begin
						opcode <= NOP;
						if(count == 0) 
							begin
								rfshcnt <= RFSHDEL;
								bsy <= 0;
								sdwait <= 1;
								state <= 10;
							end
					end
				//************************************Конец инициализации************************************
				10: //IDDLE
					begin
						opcode <= NOP;
						sadd <= 0;
						state <= 10;
						bsy <= 0;
						if(rfshcnt == 0) state <= 17;
						else
							begin
								if(!(rd & wr)) state <= 11;
							end
					end
				11: //ACTIVE
					begin
						bsy <= 1;
						tadd[23:0] <= ADD[23:0];
						bank[1:0] <= ADD[23:22];
						sadd[12:0] <= ADD[21:9];		
						if(!wr)
							begin
								trw <= 1;
								tdat[15:0] <= DI[15:0];
							end
						else trw <= 0;
						opcode <= ACTIVE;			
						count <= TRCD - 1;
						state <= 12;
					end	
				12: //Wait 2 clocks
					begin
						opcode <= NOP;
						if(count == 0) 
							begin
								if(trw) state <= 15; //Запись
								else state <= 13; 	//Чтение
							end
					end					
				13: //READ
					begin
						opcode <= READ;
						bank[1:0] <= tadd[23:22];
						sadd[8:0] <= tadd[8:0];
						sadd[10] <= 1; //AUTO PRECHARGE: 0 - DIS, 1 - EN;
						count <= TRCD + RBURST;
						state <= 14;
					end		
				14: //Защёлкиваем данные в выходной регистр (4-3-2-1 такты)
					begin
						opcode <= NOP;
						case(count)
							1: sdo[15:0] <= DIN[15:0];
							0: state <= 19;
						endcase			
					end
				15: //WRITE
					begin
						opcode <= WRITE;
						bank[1:0] <= tadd[23:22];
						sadd[8:0] <= tadd[8:0];
						sadd[10] <= 1; //AUTO PRECHARGE: 0 - DIS, 1 - EN;
						count <= TRCD + 4;
						state <= 16;
					end
				16: //Защёлкиваем данные в выходной регистр (4-3-2-1 такты)
					begin
						opcode <= NOP;
						if(count == 0) state <= 19;
					end
				17: //REFRESH
					begin
						bsy <= 1;
						opcode <= AUTOREFRESH;
						count <= TRCD;
						state <= 18;
					end
				18: //
					begin
						opcode <= NOP;
						if(count == 0)
							begin	
								rfshcnt <= RFSHDEL; 
								state <= 19; 
							end
					end
				19: //Debug
					begin
						bsy <= 0;
						state <= 10;
					end
			endcase
		end
end

assign rdy = ~bsy;
assign SDWAIT = sdwait;

endmodule












