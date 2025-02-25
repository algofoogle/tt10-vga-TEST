# SPDX-FileCopyrightText: © 2025 Anton Maurovic
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles
import time
from os import environ as env
import re


# @cocotb.test()
# async def test_project(dut):
#     dut._log.info("Start")

#     # Set the clock period to 10 us (100 KHz)
#     clock = Clock(dut.clk, 10, units="us")
#     cocotb.start_soon(clock.start())

#     # Reset
#     dut._log.info("Reset")
#     dut.ena.value = 1
#     dut.ui_in.value = 0
#     dut.uio_in.value = 0
#     dut.rst_n.value = 0
#     await ClockCycles(dut.clk, 10)
#     dut.rst_n.value = 1

#     dut._log.info("Test project behavior")

#     # Set the input values you want to test
#     dut.ui_in.value = 20
#     dut.uio_in.value = 30

#     # Wait for one clock cycle to see the output values
#     await ClockCycles(dut.clk, 1)

#     # The following assersion is just an example of how to check the output values.
#     # Change it to match the actual expected output of your module:
#     # assert dut.uo_out.value == 50

#     # Keep testing the module by changing the input values, waiting for
#     # one or more clock cycles, and asserting the expected output values.


HIGH_RES        = float(env.get('HIGH_RES')) if 'HIGH_RES' in env else None # If not None, scale H res by this, and step by CLOCK_PERIOD/HIGH_RES instead of unit clock cycles.
CLOCK_PERIOD    = float(env.get('CLOCK_PERIOD') or 40.0) # Default 40.0 (period of clk oscillator input, in nanoseconds)
FRAMES          =   int(env.get('FRAMES')       or   10) # Default 3 (total frames to render)

print(f"""
Test parameters (can be overridden using ENV vars):
---     HIGH_RES: {HIGH_RES}
--- CLOCK_PERIOD: {CLOCK_PERIOD}
---       FRAMES: {FRAMES}
""")

# Make sure all bidir pins are configured as they should be,
# for this design:
def check_uio_out(dut):
    # Make sure 2 LSB are outputs,
    # and all but [5] (bidir) of the rest are inputs:
    assert re.match('11111111', dut.uio_oe.value.binstr)

# This can represent hard-wired stuff:
def set_default_start_state(dut):
    dut.ena.value       = 0b1
    dut.osel.value      = 0b00
    dut.inymode.value   = 0b000
    dut.mixnoise.value  = 0b0
    dut.usewobble.value = 0b0



@cocotb.test()
async def test_frames(dut):
    """
    Generate a number of full video frames and write to frame-###.ppm
    """

    dut._log.info("Starting test_frames...")

    frame_count = FRAMES # No. of frames to render.
    hrange = 800
    frame_height = 525
    vrange = frame_height
    hres = HIGH_RES or 1

    print(f"Rendering {frame_count} full frame(s)...")

    set_default_start_state(dut)
    # Start with reset released:
    dut.rst_n.value = 1

    clk = Clock(dut.clk, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clk.start())

    # Wait 3 clocks...
    await ClockCycles(dut.clk, 3)
    check_uio_out(dut)
    dut._log.info("Assert reset...")
    # ...then assert reset:
    dut.rst_n.value = 0
    # ...and wait another 10 clocks...
    await ClockCycles(dut.clk, 10)
    check_uio_out(dut)
    dut._log.info("Release reset...")
    # ...then release reset:
    dut.rst_n.value = 1
    x_count = 0 # Counts unknown signal values.
    z_count = 0
    sample_count = 0 # Total count of pixels or samples.

    for frame in range(frame_count):
        render_start_time = time.time()

        nframe = frame + 1

        # --- Tests we do for each frame ---
        # (NOTE: New states pushed in one frame render in the next,
        # and this has been accounted for in the design below, hence `nframe`):
        # Frame index:
        # 000. ???

        # # Frame 0 will render as per normal (not really controllable).
        # if nframe in [1,2]:
        #     # Frames 1 & 2 will render per typical design behaviour.
        #     pass

        # elif nframe == 3:
        #     # Frame 3 will turn off inc_px/py:
        #     dut.inc_px.value = 0
        #     dut.inc_py.value = 0


        # Create PPM file to visualise the frame, and write its header:
        img = open(f"frames_out/frame-{frame:03d}.ppm", "w")
        img.write("P3\n")
        img.write(f"{int(hrange*hres)} {vrange:d}\n")
        img.write("255\n")

        for n in range(vrange): # 525 lines * however many frames in frame_count
            print(f"Rendering line {n} of frame {frame}")
            for n in range(int(hrange*hres)): # 800 pixel clocks per line.
                if n % 100 == 0:
                    print('.', end='')
                if 'x' in dut.rgb.value.binstr:
                    # Output is unknown; make it green:
                    r = 0
                    g = 255
                    b = 0
                elif 'z' in dut.rgb.value.binstr:
                    # Output is HiZ; make it magenta:
                    r = 255
                    g = 0
                    b = 255
                else:
                    rr = dut.rr.value
                    gg = dut.gg.value
                    bb = dut.bb.value
                    hsyncb = 255 if dut.hsync.value.binstr=='x' else (0==dut.hsync.value)*0b110000
                    vsyncb = 128 if dut.vsync.value.binstr=='x' else (0==dut.vsync.value)*0b110000
                    r = (rr << 6) | hsyncb
                    g = (gg << 6) | vsyncb
                    b = (bb << 6)
                sample_count += 1
                if 'x' in (dut.rgb.value.binstr + dut.hsync.value.binstr + dut.vsync.value.binstr):
                    x_count += 1
                if 'z' in (dut.rgb.value.binstr + dut.hsync.value.binstr + dut.vsync.value.binstr):
                    z_count += 1
                img.write(f"{r} {g} {b}\n")
                if HIGH_RES is None:
                    await ClockCycles(dut.clk, 1) 
                else:
                    await Timer(CLOCK_PERIOD/hres, units='ns')
        img.close()
        render_stop_time = time.time()
        delta = render_stop_time - render_start_time
        print(f"[{render_stop_time}: Frame simulated in {delta} seconds]")
    print("Waiting 1 more clock, for start of next line...")
    await ClockCycles(dut.clk, 1)

    # await toggler

    print(f"DONE: Out of {sample_count} pixels/samples, got: {x_count} 'x'; {z_count} 'z'")
