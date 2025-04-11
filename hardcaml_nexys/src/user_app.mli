open Hardcaml

module I : sig
  type 'a t = {
    clock : 'a;
    reset : 'a;
    switches : 'a; [@bits 16]
    axi_m2s : 'a Axi.Master_to_slave.t;
  }
  [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t = { axi_s2m : 'a Axi.Slave_to_master.t }
  [@@deriving sexp_of, hardcaml]
end

val hierarchical :
  ?name:string ->
  (Scope.t -> Signal.t I.t -> Signal.t O.t) ->
  Scope.t ->
  Signal.t I.t ->
  Signal.t O.t
