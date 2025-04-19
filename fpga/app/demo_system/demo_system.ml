open! Base
open! Hardcaml
open! Tpu_nexys
open! Signal

let create scope (input : _ App.I.t) =
  ignore scope;
  ignore input;
  { App.O.unused = Signal.gnd }

let () =
  Stdio.print_string (Tpu_nexys.Rtl_generator.generate "demo_system_top" create)
