open! Base
open Hardcaml
open Hardcaml_nexys
open Signal

let create _scope (input : _ User_app.I.t) =
  let leds = wire Nexys.num_leds in
  leds <== input.switches;
  { User_app.O.leds }

let () = Hardcaml_nexys.Rtl_generator.generate create (To_channel Stdio.stdout)