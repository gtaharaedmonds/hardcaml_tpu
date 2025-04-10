open Base
open Hardcaml

module I = struct
  type 'a t = {
    sys_clock : 'a;
    reset : 'a;
    switches : 'a; [@bits Nexys.num_switches]
  }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = { leds : 'a [@bits Nexys.num_leds] }
  [@@deriving sexp_of, hardcaml]
end

let check_port_width (name, width) signal =
  if width <> Signal.width signal then
    raise_s [%message "Signal width mismatch" (name : string) (width : int)]

let hierarchical ?(name = "user_application") create_fn scope input =
  let module Hierarchy = Hierarchy.In_scope (I) (O) in
  I.(iter2 t input ~f:check_port_width);
  let output = Hierarchy.hierarchical ~name ~scope create_fn input in
  output
