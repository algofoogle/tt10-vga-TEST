// This is just a quick test to try wrapping my design
// (represented in this case as a complete TT digital project submission)
// in a module that matches the ports defined in the TT analog project DEFs,
// but then to be fed to OL2 using a modified DEF.
// Basically the only way this module differs from a regular TT digital
// project submission is that it includes ua[7:0].

// This experiment is now done, and I'm moving on to analog_control_wrapper.v

module tt_um_algofoogle_tt10_vga_test_wrapped (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n,    // reset_n - low to reset
    inout  wire [7:0] ua
);

    tt_um_algofoogle_tt10_vga_test tt_project (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

endmodule
