open Hardcaml

module I : sig
  type 'a t = { clock : 'a; reset : 'a } [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t = { unused : 'a } [@@deriving sexp_of, hardcaml]
end

val hierarchical :
  ?name:string ->
  (Scope.t -> Signal.t I.t -> Signal.t O.t) ->
  Scope.t ->
  Signal.t I.t ->
  Signal.t O.t
