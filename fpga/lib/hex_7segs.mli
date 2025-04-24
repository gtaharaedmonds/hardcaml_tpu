open Base
open Hardcaml

module I : sig
  type 'a t = { clock : 'a; reset : 'a; enables : 'a list; values : 'a list }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { anodes : 'a list; cathodes : 'a; decimal_point : 'a }
  [@@deriving hardcaml]
end

val hierarchical : ?name:string -> Scope.t -> Signal.t I.t -> Signal.t O.t
