//
//Written by GowinSynthesis
//Tool Version "V1.9.12 (64-bit)"
//Fri Feb  6 09:51:25 2026

//Source file index table:
//file0 "\C:/Gowin/Gowin_V1.9.12_x64/IDE/ipcore/DDR/data/ddr.v"
`timescale 100 ps/100 ps
module DDIO (
  din,
  clk,
  q
)
;
input [1:0] din;
input clk;
output [0:0] q;
wire \oddr_gen[0].oddr_inst_1_Q1 ;
wire VCC;
wire GND;
  ODDR \oddr_gen[0].oddr_inst  (
    .Q0(q[0]),
    .Q1(\oddr_gen[0].oddr_inst_1_Q1 ),
    .D0(din[0]),
    .D1(din[1]),
    .TX(GND),
    .CLK(clk) 
);
  VCC VCC_cZ (
    .V(VCC)
);
  GND GND_cZ (
    .G(GND)
);
  GSR GSR (
    .GSRI(VCC) 
);
endmodule /* DDIO */
