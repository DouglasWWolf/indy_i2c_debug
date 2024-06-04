//Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2021.1 (lin64) Build 3247384 Thu Jun 10 19:36:07 MDT 2021
//Date        : Tue Jun  4 03:18:15 2024
//Host        : simtool-5 running 64-bit Ubuntu 20.04.6 LTS
//Command     : generate_target top_level_wrapper.bd
//Design      : top_level_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module top_level_wrapper
   (I2C_MUX_ENABLE,
    QSFP_IIC_scl_io,
    QSFP_IIC_sda_io,
    QSFP_LP,
    QSFP_MODSEL_L,
    QSFP_RESET_L,
    pcie_mgt_rxn,
    pcie_mgt_rxp,
    pcie_mgt_txn,
    pcie_mgt_txp,
    pcie_refclk_clk_n,
    pcie_refclk_clk_p);
  output I2C_MUX_ENABLE;
  inout QSFP_IIC_scl_io;
  inout QSFP_IIC_sda_io;
  output [1:0]QSFP_LP;
  output [1:0]QSFP_MODSEL_L;
  output [1:0]QSFP_RESET_L;
  input [15:0]pcie_mgt_rxn;
  input [15:0]pcie_mgt_rxp;
  output [15:0]pcie_mgt_txn;
  output [15:0]pcie_mgt_txp;
  input [0:0]pcie_refclk_clk_n;
  input [0:0]pcie_refclk_clk_p;

  wire I2C_MUX_ENABLE;
  wire QSFP_IIC_scl_i;
  wire QSFP_IIC_scl_io;
  wire QSFP_IIC_scl_o;
  wire QSFP_IIC_scl_t;
  wire QSFP_IIC_sda_i;
  wire QSFP_IIC_sda_io;
  wire QSFP_IIC_sda_o;
  wire QSFP_IIC_sda_t;
  wire [1:0]QSFP_LP;
  wire [1:0]QSFP_MODSEL_L;
  wire [1:0]QSFP_RESET_L;
  wire [15:0]pcie_mgt_rxn;
  wire [15:0]pcie_mgt_rxp;
  wire [15:0]pcie_mgt_txn;
  wire [15:0]pcie_mgt_txp;
  wire [0:0]pcie_refclk_clk_n;
  wire [0:0]pcie_refclk_clk_p;

  IOBUF QSFP_IIC_scl_iobuf
       (.I(QSFP_IIC_scl_o),
        .IO(QSFP_IIC_scl_io),
        .O(QSFP_IIC_scl_i),
        .T(QSFP_IIC_scl_t));
  IOBUF QSFP_IIC_sda_iobuf
       (.I(QSFP_IIC_sda_o),
        .IO(QSFP_IIC_sda_io),
        .O(QSFP_IIC_sda_i),
        .T(QSFP_IIC_sda_t));
  top_level top_level_i
       (.I2C_MUX_ENABLE(I2C_MUX_ENABLE),
        .QSFP_IIC_scl_i(QSFP_IIC_scl_i),
        .QSFP_IIC_scl_o(QSFP_IIC_scl_o),
        .QSFP_IIC_scl_t(QSFP_IIC_scl_t),
        .QSFP_IIC_sda_i(QSFP_IIC_sda_i),
        .QSFP_IIC_sda_o(QSFP_IIC_sda_o),
        .QSFP_IIC_sda_t(QSFP_IIC_sda_t),
        .QSFP_LP(QSFP_LP),
        .QSFP_MODSEL_L(QSFP_MODSEL_L),
        .QSFP_RESET_L(QSFP_RESET_L),
        .pcie_mgt_rxn(pcie_mgt_rxn),
        .pcie_mgt_rxp(pcie_mgt_rxp),
        .pcie_mgt_txn(pcie_mgt_txn),
        .pcie_mgt_txp(pcie_mgt_txp),
        .pcie_refclk_clk_n(pcie_refclk_clk_n),
        .pcie_refclk_clk_p(pcie_refclk_clk_p));
endmodule
