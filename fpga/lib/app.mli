open Hardcaml

module I : sig
  type 'a t = { clock : 'a; reset : 'a; axi : 'a Axi.Master_to_slave.t }
  [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t = { axi : 'a Axi.Slave_to_master.t } [@@deriving sexp_of, hardcaml]
end

val hierarchical :
  ?name:string ->
  (Scope.t -> Signal.t I.t -> Signal.t O.t) ->
  Scope.t ->
  Signal.t I.t ->
  Signal.t O.t
