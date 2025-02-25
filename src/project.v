/*
 * Copyright (c) 2025 Anton Maurovic <anton@foogle.com>
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_algofoogle_tt10_vga_test (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [7:0] RFull;
  wire [7:0] GFull;
  wire [7:0] BFull;

  // TinyVGA PMOD
  assign uo_out = {
    hsync,
    BFull[6], GFull[6], RFull[6],
    vsync,
    BFull[7], GFull[7], RFull[7]
  };

  // All output pins must be assigned. If not used, assign to 0.
  assign uio_oe  = 8'b11111111; // All outputs.

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, uio_in, ui_in[7], 1'b0};

  wire [23:0] rgb;

  wire [2:0] inymode = ui_in[4:2];
  wire mixnoise = ui_in[5];
  wire usewobble = ui_in[6];

  algofoogle_tt10_vga_test_digital core_design (
    .clk(clk),
    .rst_n(rst_n),
    .inymode(inymode),
    .mixnoise(mixnoise),
    .usewobble(usewobble),
    .hsync(hsync),
    .vsync(vsync),
    .rgb(rgb)
  );

  assign RFull = rgb[23:16];
  assign GFull = rgb[15:8];
  assign BFull = rgb[7:0];

  wire [1:0] osel = ui_in[1:0];

  assign uio_out =
    osel == 0 ? RFull :
    osel == 1 ? GFull :
    osel == 2 ? BFull :
                8'd0;
                // R^G^B;

endmodule
