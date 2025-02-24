<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Uses a bunch of digital logic to create funky 24-bit VGA pattern outputs internally, then selects subsets of those outputs to make available on the various TT IOs depending on selections specified by `ui_in[1:0]`. Mainly intended to test synthesis and final logic size (rather than to actually submit).

## How to test

Supply a ~25MHz clock, connect Tiny VGA PMOD (or similar) to `uo_out`, and select which optional colour bank you want to output via `ui_in[1:0]`.

## External hardware

Tiny VGA PMOD.
