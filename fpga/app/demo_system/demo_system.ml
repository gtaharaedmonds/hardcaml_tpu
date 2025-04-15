open! Base
open! Hardcaml
open! Tpu_nexys

let create scope (input : _ App.I.t) =
  let reg_spec = Reg_spec.create ~reset:input.reset ~clock:input.clock () in
  let write_modes = [ Hardcaml_axi.Register_mode.hold ] in
  let read_values = [ Signal.of_int ~width:Axi.Config.data_bits 52 ] in
  let regs =
    Axi.Register_bank.create scope ~reg_spec ~axi_master:input.axi ~write_modes
      ~read_values
  in
  { App.O.axi = regs.slave }

let () =
  Stdio.print_string (Tpu_nexys.Rtl_generator.generate "demo_system_top" create)
