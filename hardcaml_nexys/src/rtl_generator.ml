open! Base
open! Hardcaml
open! Signal

type create_fn = Scope.t -> Signal.t User_app.I.t -> Signal.t User_app.O.t

module Top = struct
  module I = struct
    type 'a t = {
      reset_n : 'a;
      sys_clock : 'a;
      switches : 'a; [@bits Nexys.num_switches]
    }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = { leds : 'a [@bits Nexys.num_leds] }
    [@@deriving sexp_of, hardcaml]
  end

  let create (create_fn : create_fn) scope (input : _ I.t) =
    let user_app =
      User_app.hierarchical create_fn scope
        {
          sys_clock = input.sys_clock;
          reset = ~:(input.reset_n);
          switches = input.switches;
        }
    in
    { O.leds = user_app.leds }
end

let generate (create_fn : create_fn) (output_mode : Rtl.Output_mode.t) =
  let module C = Circuit.With_interface (Top.I) (Top.O) in
  let scope = Scope.create () in
  let circuit =
    C.create_exn ~name:"hardcaml_nexys_top" (Top.create create_fn scope)
  in
  let database = Scope.circuit_database scope in
  Rtl.output ~database ~output_mode Rtl.Language.Verilog circuit