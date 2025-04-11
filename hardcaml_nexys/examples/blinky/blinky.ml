open! Base
open! Hardcaml
open! Hardcaml_nexys

let create _scope (input : _ User_app.I.t) =
  ignore input;
  let axi_s2m = Axi.Slave_to_master.Of_signal.of_int 0 in
  { User_app.O.axi_s2m }

let () = Hardcaml_nexys.Rtl_generator.generate create (To_channel Stdio.stdout)
