open! Base
open! Hardcaml
open! Tpu_nexys
open! Signal

let create scope (input : _ App.I.t) =
  let reg_spec = Reg_spec.create ~clear:input.reset ~clock:input.clock () in
  let write_modes = [ Hardcaml_axi.Register_mode.hold ] in
  let read_values = [ Signal.of_int ~width:Axi.Config.data_bits 98 ] in
  let regs =
    Axi.Register_bank.create scope ~reg_spec ~axi_master:input.axi ~write_modes
      ~read_values
  in
  { App.O.axi = regs.slave }

(* let create scope (input : _ App.I.t) =
  let reg_spec = Reg_spec.create ~clear:input.reset ~clock:input.clock () in
  let read_in = wire Axi.Config.data_bits in
  let write_modes = [ Hardcaml_axi.Register_mode.hold ] in
  let read_values = [ read_in ] in
  let regs =
    Axi.Register_bank.create scope ~reg_spec ~axi_master:input.axi ~write_modes
      ~read_values
  in
  let () =
    match regs.data.write_values with
    | [ write_val ] ->
        let read_reg = reg reg_spec ~enable:write_val.valid write_val.value in
        read_in <== read_reg
    | _ -> raise_s [%message "error"]
  in
  { App.O.axi = regs.slave } *)

(* let create _scope (input : _ App.I.t) =
  (* let reg_spec = Reg_spec.create ~reset:input.reset ~clock:input.clock () in
  let write_modes = [ Hardcaml_axi.Register_mode.hold ] in
  let read_values = [ Signal.of_int ~width:Axi.Config.data_bits 52 ] in
  let regs =
    Axi.Register_bank.create scope ~reg_spec ~axi_master:input.axi ~write_modes
      ~read_values *)
  (* in *)
  {
    App.O.axi =
      {
        Axi.Slave_to_master.awready = input.axi.rready;
        wready = input.axi.rready;
        bresp = Signal.of_int ~width:2 3;
        bvalid = input.axi.bready;
        arready = input.axi.wvalid;
        rdata = input.axi.wdata;
        rresp = Signal.of_int ~width:2 3;
        rvalid = input.axi.awvalid;
      };
  } *)

let () =
  Stdio.print_string (Tpu_nexys.Rtl_generator.generate "demo_system_top" create)
