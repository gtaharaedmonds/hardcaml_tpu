open Base
open! Hardcaml

module Row : sig
  type 'a t = { elements : 'a list [@bits data_bits] [@length size] }
  [@@deriving hardcaml]
end

type 'a t = { rows : 'a Row.t list [@length size] } [@@deriving hardcaml]

val get : 'a t -> row:int -> col:int -> 'a
val iteri : 'a t -> f:(int -> int -> 'a -> unit) -> unit
