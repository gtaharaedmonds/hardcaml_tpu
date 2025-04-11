open! Base
open! Hardcaml
open! Tpu_nexys

let create _scope (input : _ App.I.t) =
  ignore input;
  let axi_s2m = Axi.Slave_to_master.Of_signal.of_int 0 in
  { App.O.axi_s2m }

let () =
  Tpu_nexys.Rtl_generator.generate "blinky_top" create (To_channel Stdio.stdout)
