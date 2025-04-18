open! Base
open! Hardcaml

(* 2D array type for Hardcaml *)

module type Config = sig
  val size : int
  val bits : int
end

module type S = sig
  module Row : sig
    type 'a t = { elements : 'a list } [@@deriving hardcaml]
  end

  type 'a t = { rows : 'a Row.t list } [@@deriving hardcaml]

  module Config : Config

  val create : f:(int -> int -> 'a) -> 'a t
  val get : 'a t -> row:int -> col:int -> 'a
  val iteri : 'a t -> f:(int -> int -> 'a -> unit) -> unit
  val mapi : 'a t -> f:(int -> int -> 'a -> 'b) -> 'b t
end

module type Matrix = sig
  module type S = S

  module Make (Config : Config) : S
end
