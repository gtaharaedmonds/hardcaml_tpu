open Base
open! Hardcaml

module I : sig
  type 'a t = { clock : 'a; reset : 'a; load : 'a; input : 'a Matrix.t }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { wavefront : 'a list [@bits data_bits] [@length size] }
  [@@deriving hardcaml]
end

val create : Signal.t I.t -> Signal.t O.t
