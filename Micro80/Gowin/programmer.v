
//`define SDRAM
`define SRAM


module programmer(
	input wire clk,
	input wire rst,
	output wire PROG,
	//SPI Flash
	output wire SPI_CS,
	output wire SPI_MOSI,
	output wire SPI_SCK,
	input wire SPI_MISO,
	//SRAM
	output wire[18:0] SRAMADD,
	output wire[7:0] SRAMDO,
`ifdef SDRAM
	input wire DEV_RDY,
`endif	
	output wire SRAMWE//

);

parameter COUNT = 131072; //Количество записываемых байт памяти

wire[7:0]SPIDI,SPIDO;
wire SPISTART,SPIRDY;

spi msp(.clk(clk),.rst(rst),.start(SPISTART),.DIN(SPIDI),.DOUT(SPIDO),
			.bsy(SPIRDY),.miso(SPI_MISO),.mosi(SPI_MOSI),.sck(SPI_SCK));


reg spi_cs;
reg prst;
reg rwr;
reg spi_start;
reg[7:0] spi_rd, spi_wr;
reg[18:0] spi_cnt;
reg[5:0] spi_state,spi_return;
reg[3:0] wr_del;

always@(posedge clk or negedge rst)
	begin
		if(!rst)
			begin
				prst <= 0;		//Доп. сброс
				spi_cs <= 0;
				spi_rd <= 0;
				spi_wr <= 0;
				spi_state <= 0;
				spi_start <= 0;
				spi_cnt <= 0;
				spi_return <= 0;
				rwr <= 0;
				wr_del <= 0;
			end
		else
			begin
				if(wr_del > 0) wr_del <= wr_del - 1;
			
				case(spi_state)				
`ifdef SRAM				
					0: //Begin
						begin
							prst <= 1;
							spi_cs <= 0;
							spi_state <= 1;
						end	
					1: //Start
						begin 
							spi_cs <= 1;
							spi_wr <= 8'h03;
							spi_return <= 2;
							spi_state <= 12; //Процедура записи байта в SPI
						end										
					2: 
						begin 
							spi_wr <= 8'h00;
							spi_return <= 3;
							spi_state <= 12;
						end
					3: 
						begin 
							spi_wr <= 8'h00;
							spi_return <= 4;
							spi_state <= 12;
						end
					4: 
						begin 
							spi_wr <= 8'h00;
							spi_return <= 5;
							spi_state <= 12;
						end
					5: 
						begin 
							spi_wr <= 8'hFF;
							spi_return <= 6;
							spi_state <= 12;
						end
					6: //Запись байта в SRAM 
						begin 
							rwr <= 1;
							wr_del <= 7;
							spi_state <= 7;
						end	
					7: 
						begin 
							if(wr_del == 0)
								begin
									rwr <= 0;
									spi_state <= 8;
									wr_del <= 5;
								end
							else spi_state <= 7;
						end
					8: 
						begin 
						    if(wr_del == 0)
						         begin
							         spi_cnt <= spi_cnt + 1;
							         spi_state <= 9;
							     end
							else spi_state <= 8;
						end					
					9: 
						begin 
							if(spi_cnt >= COUNT) spi_state <= 10;
							else spi_state <= 5;
						end	
`endif
`ifdef SDRAM
					0: //Begin
						begin
							if(DEV_RDY)
								begin
									prst <= 1;
									spi_cs <= 0;
									spi_state <= 1;
								end
						end
					1: //Start
						begin 
							spi_cs <= 1;
							spi_wr <= 8'h03;
							spi_return <= 2;
							spi_state <= 12; //Процедура записи байта в SPI
						end										
					2: 
						begin 
							spi_wr <= 8'h00;
							spi_return <= 3;
							spi_state <= 12;
						end
					3: 
						begin 
							spi_wr <= 8'h00;
							spi_return <= 4;
							spi_state <= 12;
						end
					4: 
						begin 
							spi_wr <= 8'h00;
							spi_return <= 5;
							spi_state <= 12;
						end
					5: 
						begin 
							spi_wr <= 8'hFF;
							spi_return <= 6;
							spi_state <= 12;
						end
					6: //Запись байта в SRAM 
						begin 
							rwr <= 1;
							//wr_del <= 7;
							spi_state <= 7;
						end	
					7: 
						begin 
							if(DEV_RDY == 0)
								begin
									rwr <= 0;
									spi_state <= 8;
								end
							else spi_state <= 7;
						end
					8: 
						begin 
							spi_cnt <= spi_cnt + 1;
							spi_state <= 9;
						end					
					9: 
						begin 
							if(spi_cnt >= COUNT) spi_state <= 10;
							else 
								begin
									if(DEV_RDY) spi_state <= 5;
									else spi_state <= 9;
								end
						end				
`endif			
					10: //IDDLE 
						begin 
							prst <= 0;
							spi_cs <= 0;
							spi_cnt <= 0;
							spi_state <= 10;
						end			
			
					12: //SPI write byte
						begin
							spi_start <= 1;
							spi_state <= 13;
						end	
					13: 
						begin
							if(SPIRDY)
								begin
									spi_start <= 0;
									spi_state <= 14;
								end
							else spi_state <= 13;
						end	
					14: 
						begin
							if(!SPIRDY)spi_state <= 15;
							else spi_state <= 14;
						end
					15: 
						begin
							spi_rd <= SPIDO;
							spi_state <= spi_return;
						end		
				endcase
			end
	end
	
assign PROG = prst;
assign SRAMWE = ~rwr;
assign SRAMADD[18:0] = spi_cnt[18:0];
assign SRAMDO = spi_rd;
assign SPI_CS = ~spi_cs;
assign SPIDI = spi_wr;
assign SPISTART = spi_start;


endmodule
