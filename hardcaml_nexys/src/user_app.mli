open Hardcaml

module I : sig
  type 'a t = {
    sys_clock : 'a;
    reset : 'a;
    switches : 'a; [@bits Nexys.num_switches]
  }
  [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t = { leds : 'a [@bits Nexys.num_leds] }
  [@@deriving sexp_of, hardcaml]
end

val hierarchical :
  ?name:string ->
  (Scope.t -> Signal.t I.t -> Signal.t O.t) ->
  Scope.t ->
  Signal.t I.t ->
  Signal.t O.t
