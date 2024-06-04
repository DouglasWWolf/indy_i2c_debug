//Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Command: generate_target bd_9bbd_wrapper.bd
//Design : bd_9bbd_wrapper
//Purpose: IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module bd_9bbd_wrapper
   (clk,
    probe0,
    probe1,
    probe10,
    probe11,
    probe12,
    probe13,
    probe14,
    probe2,
    probe3,
    probe4,
    probe5,
    probe6,
    probe7,
    probe8,
    probe9);
  input clk;
  input [7:0]probe0;
  input [6:0]probe1;
  input [0:0]probe10;
  input [31:0]probe11;
  input [7:0]probe12;
  input [0:0]probe13;
  input [0:0]probe14;
  input [15:0]probe2;
  input [0:0]probe3;
  input [7:0]probe4;
  input [31:0]probe5;
  input [0:0]probe6;
  input [2:0]probe7;
  input [31:0]probe8;
  input [31:0]probe9;

  wire clk;
  wire [7:0]probe0;
  wire [6:0]probe1;
  wire [0:0]probe10;
  wire [31:0]probe11;
  wire [7:0]probe12;
  wire [0:0]probe13;
  wire [0:0]probe14;
  wire [15:0]probe2;
  wire [0:0]probe3;
  wire [7:0]probe4;
  wire [31:0]probe5;
  wire [0:0]probe6;
  wire [2:0]probe7;
  wire [31:0]probe8;
  wire [31:0]probe9;

  bd_9bbd bd_9bbd_i
       (.clk(clk),
        .probe0(probe0),
        .probe1(probe1),
        .probe10(probe10),
        .probe11(probe11),
        .probe12(probe12),
        .probe13(probe13),
        .probe14(probe14),
        .probe2(probe2),
        .probe3(probe3),
        .probe4(probe4),
        .probe5(probe5),
        .probe6(probe6),
        .probe7(probe7),
        .probe8(probe8),
        .probe9(probe9));
endmodule
