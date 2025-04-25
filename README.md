# hardcaml_tpu

Simple systolic array for multiplying matrices, written with
[Hardcaml](https://github.com/janestreet/hardcaml). Eventually I'm hoping to try
this out on accelerating neural network inference.

Very brief overview: 
- Streams weights, data, and accumulated results in and out of the array via AXI streams
- Xilinx DMA IP cores handle moving the data from memory to the streams and vice-versa
- Using a [neorv32](https://github.com/stnolting/neorv32) RISC-V soft core.
  Although it would be cool to do everything in hardware, the rapid iteration
  with a CPU is too nice to give up, especially during debugging.
- Custom Rust drivers for all of the above in `sw/`

Synthesized and tested for the Digilent [Nexys A7](https://digilent.com/reference/programmable-logic/nexys-a7/start). 
Board support was heavily based off of
[hardcaml_arty](https://github.com/fyquah/hardcaml_arty). 

A 16x16 systolic
array, wth 8 bits for weights, 8 bits for data, and 32 bits for accumulated
results is all I can currently fit on my FPGA (Nexys A7 100T), using about >70%
of available LUTs. 

