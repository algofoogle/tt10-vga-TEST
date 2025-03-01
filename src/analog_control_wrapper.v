// This is the digital control block, but with a funky shape,
// that OpenLane 2 will synthesise to interface with the analog SEGDACs
// that I'll place manually afterwards.

module analog_control_wrapper (
    // Standard TT digital IOs, on the North side:
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n,    // reset_n - low to reset

    // Outputs for interfacing with the SEGDACs, on the South side:
    output wire [11:0] R, // 4 segments, 3 each, thermo-coded: R[11:9]<-red[7:6], R[8:6]<-red[5:4], etc.
    output wire [11:0] G,
    output wire [11:0] B,
    // Vbias controls (the R/G/B colour channels' biases are copies of each other):
    output wire Rbias1, Rbias2, Rbias3,
    output wire Gbias1, Gbias2, Gbias3,
    output wire Bbias1, Bbias2, Bbias3
);

    // VGA signals
    wire hsync;
    wire vsync;
    wire [23:0] rgb; // Actually it's BGR order: {B[7:0], G[7:0], R[7:0]}

    // TinyVGA PMOD (digital RGB222 version output):
    assign uo_out = {
        hsync,
        // BGR order, MSB-1:
        rgb[22], rgb[14], rgb[6],
        vsync,
        // BGR order, MSB:
        rgb[23], rgb[15], rgb[7]
    };

    assign uio_oe  = 8'b00000000; // All inputs.
    assign uio_out = 8'b00000000; // Unused output paths.

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, uio_in, ui_in[7:5], 1'b0};

    wire bias1 = ui_in[5];
    wire bias2 = ui_in[6];
    wire bias3 = ui_in[7];

    assign {Rbias1,Rbias2,Rbias3} = {bias1,bias2,bias3};
    assign {Gbias1,Gbias2,Gbias3} = {bias1,bias2,bias3};
    assign {Bbias1,Bbias2,Bbias3} = {bias1,bias2,bias3};
    wire usewobble      = ui_in[4];
    wire mixnoise       = ui_in[3];
    wire [2:0] inymode  = ui_in[2:0];

    algofoogle_tt10_vga_test_digital vga_pattern_gen(
        .clk        (clk),
        .rst_n      (rst_n),
        .inymode    (inymode),
        .mixnoise   (mixnoise),
        .usewobble  (usewobble),
        .hsync      (hsync),
        .vsync      (vsync),
        .rgb        (rgb)
    );

    // 4 instances (i.e. 4 segments) per each channel...
    // Note that the RGB outputs from the controller get negated here,
    // since the segdacs use NFETs (sink current, rather than sourcing).
    thermo2bit decode_r[3:0] ( .bin(~rgb[ 7: 0]), .thermo(R) );
    thermo2bit decode_g[3:0] ( .bin(~rgb[15: 8]), .thermo(G) );
    thermo2bit decode_b[3:0] ( .bin(~rgb[23:16]), .thermo(B) );

endmodule

module thermo2bit (
    input wire [1:0] bin,
    output wire [2:0] thermo
);
    assign thermo =
        bin == 0 ?  3'b000 :
        bin == 1 ?  3'b001 :
        bin == 2 ?  3'b011 :
                    3'b111;
endmodule
