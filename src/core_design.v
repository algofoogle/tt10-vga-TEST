/*
 * Copyright (c) 2025 Anton Maurovic <anton@foogle.com>
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// `define ENABLE_WOBBLE
// `define ENABLE_NOISE
// `define ENABLE_INYMODE

module algofoogle_tt10_vga_test_digital (
  input wire clk,
  input wire rst_n,
  input wire [2:0] inymode,
  input wire mixnoise,
  input wire usewobble,
  output wire hsync,
  output wire vsync,
  output wire [23:0] rgb
);

  test_hvsync_top demo(
    .clk(clk),
    .reset(~rst_n),

`ifdef ENABLE_INYMODE
    .inymode(inymode),
`else
    .inymode(0),
`endif

`ifdef ENABLE_NOISE
    .mixnoise(mixnoise),
`else
    .mixnoise(0),
`endif

`ifdef ENABLE_WOBBLE
    .usewobble(usewobble),
`else
    .usewobble(0),
`endif

    .hsync(hsync),
    .vsync(vsync),
    .rgb(rgb)
  );

endmodule



module test_hvsync_top(clk, reset, inymode, mixnoise, usewobble, hsync, vsync, rgb);

  input clk, reset, mixnoise, usewobble;
  input [2:0] inymode;
  output hsync, vsync;
  output [23:0] rgb;
  wire display_on;
  wire [9:0] hpos;
  wire [9:0] vpos;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );

  wire [2:0] patmode = 6;
  
  wire [9:0] sine_signal;
  
  sine_wave_generator sinegen(
    .clk(clk),
    .reset(reset || vpos==0),//vpos==tm[10:1]),
    //.step(hpos==0),// && vpos[0]==0),
    .step(hpos==0 && vpos[0]==0),
    .init(10'd0),
    .signal(sine_signal)
  );
  
  // localparam usewobble = 1;
  
  wire [10:0] wobble =
  usewobble ? {1'b0,((sine_signal>>5)+10'd300)} - {1'b0,hpos} :
  0;
  
  wire [7:0] ww = wobble[7:0] ^ {8{wobble[8]}};
  
  reg [19:0] tm;

  // Increment time counter at the start of each frame:
  always @(posedge clk) begin
    if (reset)
      tm <= 0;
    else if (hpos==0 && vpos==0)
      tm <= tm + 1;
  end
  
  wire patn =
  (patmode == 0) ? (((hpos&8)==0) || ((vpos&8)==0)) : // Squares
  (patmode == 1) ? (((hpos&7)==0) || ((vpos&7)==0)) : // Fine grid
  (patmode == 2) ? (((hpos&15)==0) || ((vpos&15)==0)) : // Coarse grid
  (patmode == 3) ? hpos[0] != vpos[0] : // Haze invert
  (patmode == 4) ? hpos[7] != vpos[7] : // Checker invert
  (patmode == 5) ? (hpos[9:2] ^ vpos[9:2])==tm[9:2] : // Munching squares
  (patmode == 6) ? wobble[8] : //hpos > (sine_signal>>5)+300 : // Munching squares
  0;
  
  wire [7:0] grid = 0 ? 0 : {8{patn}};
  
  //wire [9:0] vdrift = vpos+tm[9:0];
  
  // wire mixnoise = 0;
  
  wire [15:0] noise;
  wire [7:0] gg,bb;

  assign rgb = {24{display_on}} & {
    // Blue:
    (mixnoise ? noise[15:8] : 8'h00) ^ ((bb ^ grid) ^ (ww)), //(rr & {noise[15:8]}) + bb,// | aa,// & aa),// & (hpos<320 ? ~hpos[9:2] : hpos[9:2]),
    // Green:
    (mixnoise ? noise[15:8] : 8'hff) & ((gg ^ grid) ^ (ww)),// ^ {noise[15:8]},
    // Red:
    (mixnoise ? noise[15:8] : 8'h00) ^ (((~bb) ^ grid) ^ (ww))//bb ^ {noise[15:8]}
  };

  // //SMELL: Improve this to use ~&{hpos,vpos} instead of a register:
  // reg [9:0] y_prv;
  
  // always @(posedge clk) begin
  //   if (reset) begin
  //     tm <= 0;
  //     y_prv <= 0;
  //   end else begin
  //     y_prv <= vpos;
  //     if (vpos == 0 && y_prv != vpos) begin
  //         tm <= tm + 1;
  //     end
  //   end
  // end

  //localparam inymode = 0;
  // 0 = normal flow.
  // 1 = crazy crystals.
  // 2 = feather
  // 3 = alt crystals
  // 4 = crazy chains
  // 5 = sharp weave
  // 6 = bit pattern horizontal interleave
  // 7 = ice shards
  // N = just sines

  wire [9:0] iny =
  (0==inymode) ? vpos :
  (1==inymode) ? vpos&{2'd0,ww} :
  (2==inymode) ? 0 :
  (3==inymode) ? vpos|{2'd0,ww} :
  (4==inymode) ? vpos^{2'd0,ww} :
  (5==inymode) ? vpos+{2'd0,ww}<<7 :
  (6==inymode) ? vpos&{2'd0,ww}<<5 :
                 hpos^vpos;

  localparam timemode = 0;
  
  wire [19:0] t =
  (0==timemode) ? tm :
  (1==timemode) ? tm+{9'd0,wobble} :
  (2==timemode) ? tm+{12'd0,ww} :
  0;
  
  localparam inxmode = 0;
  
  wire [9:0] inx =
  (0==inxmode) ? hpos :
  (1==inxmode) ? hpos-~{2'd0,ww}>>2 :
  0;
  
  worley_noise_generator pattern(
    .inx(inx),
    .iny(iny),
    .t(t),
    //.distort(wobble[9:0]),
    .distort({2'd0,ww[7:0]}|wobble[9:0]),
    .noise(noise),
    .g(gg),
    .b(bb)
  );

endmodule

module worley_noise_generator (
  input wire [9:0] inx,
  input wire [9:0] iny,
  input wire [19:0] t,
  input wire [9:0] distort,
  output [15:0] noise,
  output [7:0] g,
  output [7:0] b
);

  // Define a small fixed grid of points
  wire [8:0] points_x[0:1];
  wire [8:0] points_y[0:1];
  
  wire [9:0] sx = inx;//{2'b0,inx[9:2]};
  wire [9:0] sy = iny;//-x+t[9:0]; //{3'b0,iny[9:3]} + {8'b0,x[1:0]};


  assign points_x[0] = 9'd300 - t[9:1];
  assign points_y[0] = 9'd200 + t[9:1];
  assign points_x[1] = 9'd100 + t[8:0];
  assign points_y[1] = 9'd400 - t[9:1];

  wire [9:0] diag = sx;
  
  wire [23:0] gap = diag*sy-{14'b0,sx}+{4'b0,t}; // xor is good on t
  
  wire [9:0] subgap = gap[17:8]+sy;//|diag;

  
  wire [15:0] distance1 = ({6'b0,sx} - {7'b0,points_x[0]}) * ({6'b0,sy} - {7'b0,points_x[0]}) - ({6'b0,sy} - {7'b0,points_y[0]}) * ({6'b0,subgap-distort+t[9:0]} - {7'b0,points_y[0]});
  wire [15:0] distance2 = ({6'b0,sy} - {7'b0,points_x[1]}) * ({6'b0,sx} + {7'b0,points_x[1]}) + ({6'b0,sx} - {7'b0,points_y[1]}) * ({6'b0,subgap+distort+t[9:0]} - {7'b0,points_y[1]});
  wire [15:0] min_dist = distance1 < distance2 ? distance1 : distance2;
  
  assign noise = ~min_dist;  // Scale down to 8-bit value
  assign g = ~distance1[15:8];
  assign b =  distance2[15:8];
  
endmodule


module sine_wave_generator (
    input wire clk,
    input wire step,
    input wire [9:0] init,
    input wire reset,
    output reg [9:0] signal
);

    reg signed [10:0] addend;      // 11-bit signed to allow for negative values
    reg [1:0] state;

    localparam STATE_UP_ACCEL   = 2'd0;
    localparam STATE_UP_DECEL   = 2'd1;
    localparam STATE_DOWN_ACCEL = 2'd2;
    localparam STATE_DOWN_DECEL = 2'd3;
  
    localparam D_MAX = 11'd30;
    localparam D_MIN = 11'd30;

    always @(posedge clk) begin
        if (reset) begin
            signal <= init;
            addend <= 11'd0;
            state  <= STATE_UP_ACCEL;
        end else if (step==1) begin
            case (state)
                STATE_UP_ACCEL: begin
                    addend <= addend + 1;      // Accelerating upwards
                  signal <= signal + addend[9:0];
                  if (addend >= D_MAX)    // Threshold for deceleration
                        state <= STATE_UP_DECEL;
                end

                STATE_UP_DECEL: begin
                    addend <= addend - 1;      // Decelerating upwards
                  signal <= signal + addend[9:0];
                    if (addend == 0)          // Inflection point at peak
                        state <= STATE_DOWN_ACCEL;
                end

                STATE_DOWN_ACCEL: begin
                    addend <= addend - 1;      // Accelerating downwards
                  signal <= signal + addend[9:0];
                  if (addend <= -D_MIN)    // Threshold for deceleration
                        state <= STATE_DOWN_DECEL;
                end

                STATE_DOWN_DECEL: begin
                    addend <= addend + 1;      // Decelerating downwards
                  signal <= signal + addend[9:0];
                    if (addend == 0)          // Inflection point at trough
                        state <= STATE_UP_ACCEL;
                end

                default: begin
                    state <= STATE_UP_ACCEL;
                end
            endcase
        end
    end

endmodule



module hvsync_generator(clk, reset, hsync, vsync, display_on, hpos, vpos);

  input clk;
  input reset;
  output reg hsync, vsync;
  output display_on;
  output reg [9:0] hpos;
  output reg [9:0] vpos;

  // declarations for TV-simulator sync parameters
  // horizontal constants
  parameter H_DISPLAY       = 640; // horizontal display width
  parameter H_BACK          =  48; // horizontal left border (back porch)
  parameter H_FRONT         =  16; // horizontal right border (front porch)
  parameter H_SYNC          =  96; // horizontal sync width
  // vertical constants
  parameter V_DISPLAY       = 480; // vertical display height
  parameter V_TOP           =  33; // vertical top border
  parameter V_BOTTOM        =  10; // vertical bottom border
  parameter V_SYNC          =   2; // vertical sync # lines
  // derived constants
  parameter H_SYNC_START    = H_DISPLAY + H_FRONT;
  parameter H_SYNC_END      = H_DISPLAY + H_FRONT + H_SYNC - 1;
  parameter H_MAX           = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
  parameter V_SYNC_START    = V_DISPLAY + V_BOTTOM;
  parameter V_SYNC_END      = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
  parameter V_MAX           = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;

  wire hmaxxed = (hpos == H_MAX) || reset;	// set when hpos is maximum
  wire vmaxxed = (vpos == V_MAX) || reset;	// set when vpos is maximum
  
  // horizontal position counter
  always @(posedge clk)
  begin
    hsync <= (hpos>=H_SYNC_START && hpos<=H_SYNC_END);
    if(hmaxxed)
      hpos <= 0;
    else
      hpos <= hpos + 1;
  end

  // vertical position counter
  always @(posedge clk)
  begin
    vsync <= (vpos>=V_SYNC_START && vpos<=V_SYNC_END);
    if(hmaxxed)
      if (vmaxxed)
        vpos <= 0;
      else
        vpos <= vpos + 1;
  end
  
  // display_on is set when beam is in "safe" visible frame
  assign display_on = (hpos<H_DISPLAY) && (vpos<V_DISPLAY);

endmodule
