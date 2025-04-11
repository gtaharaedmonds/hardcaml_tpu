open! Base
open! Hardcaml
open! Signal

type create_fn = Scope.t -> Signal.t User_app.I.t -> Signal.t User_app.O.t

module Top = struct
  module I = struct
    type 'a t = {
      reset_n : 'a;
      sys_clock : 'a;
      switches : 'a; [@bits 16]
      uart_rx : 'a;
    }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = { leds : 'a; [@bits 8] uart_tx : 'a }
    [@@deriving sexp_of, hardcaml]
  end

  let create (create_fn : create_fn) scope (input : _ I.t) =
    let clock_wizard =
      Clock_wizard.create { clk_in1 = input.sys_clock; resetn = input.reset_n }
    in
    let axi_clock = clock_wizard.clk_out1 in
    let reset_n = clock_wizard.locked in
    let axi_s2m = Axi.Slave_to_master.Of_signal.wires () in
    let cpu =
      Cpu.create
        {
          resetn = reset_n;
          clk = axi_clock;
          gpio_i = Signal.zero 8;
          uart0_rxd_i = input.uart_rx;
          axi_s2m;
        }
    in
    let user_app =
      User_app.hierarchical create_fn scope
        {
          clock = clock_wizard.clk_out1;
          reset = ~:reset_n;
          switches = input.switches;
          axi_m2s = cpu.axi_m2s;
        }
    in
    Axi.Slave_to_master.Of_signal.assign axi_s2m user_app.axi_s2m;
    { O.leds = cpu.gpio_o; uart_tx = cpu.uart0_txd_o }
end

let generate (create_fn : create_fn) (output_mode : Rtl.Output_mode.t) =
  let module C = Circuit.With_interface (Top.I) (Top.O) in
  let scope = Scope.create () in
  let circuit =
    C.create_exn ~name:"hardcaml_nexys_top" (Top.create create_fn scope)
  in
  let database = Scope.circuit_database scope in
  Rtl.output ~database ~output_mode Rtl.Language.Verilog circuit
