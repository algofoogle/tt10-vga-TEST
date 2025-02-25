`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/

// `define DUMP_VCD

module tb ();

  //NOTE: DON'T write VCD file, because it'd be huge!
`ifdef DUMP_VCD
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end
`endif

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  // --- DUT's generic IOs from the TT wrapper ---
  wire [7:0] ui_in;       // Dedicated inputs
  wire [7:0] uo_out;      // Dedicated outputs
  wire [7:0] uio_in;      // Bidir IOs: Input path
  wire [7:0] uio_out;     // Bidir IOs: Output path
  wire [7:0] uio_oe;      // Bidir IOs: Enable path (active high: 0=input, 1=output).

  reg [1:0] osel;
  assign ui_in[1:0] = osel;

  reg [2:0] inymode;
  assign ui_in[4:2] = inymode;

  reg mixnoise;
  assign ui_in[5] = mixnoise;

  reg usewobble;
  assign ui_in[6] = usewobble;

  wire hsync      = uo_out[7];
  wire vsync      = uo_out[3];

  // Design's specific Tiny VGA PMOD RrGgBb and H/Vsync pin outputs
  // (https://tinytapeout.com/specs/pinouts/#vga-output)
  wire [1:0] rr = {uo_out[0],uo_out[4]};
  wire [1:0] gg = {uo_out[1],uo_out[5]};
  wire [1:0] bb = {uo_out[2],uo_out[6]};
  wire [5:0] rgb = {rr,gg,bb}; // Just used by cocotb test bench for convenient checks.

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Replace tt_um_example with your module name:
  tt_um_algofoogle_tt10_vga_test user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
