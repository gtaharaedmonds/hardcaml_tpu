open! Base
open! Hardcaml
open! Tpu_nexys

let create _scope (input : _ App.I.t) =
  ignore input;
  { App.O.unused = Signal.gnd }

let () =
  Stdio.print_string (Tpu_nexys.Rtl_generator.generate "blinky_top" create)
