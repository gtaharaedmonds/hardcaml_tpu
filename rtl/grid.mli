open Base

(* basic 2D array type *)

type 'a t = 'a Array.t Array.t

val create : int -> f:(int -> int -> 'a) -> 'a t
val get : 'a t -> row:int -> col:int -> 'a
val iteri : 'a t -> f:(int -> int -> 'a -> unit) -> unit
val mapi : 'a t -> f:(int -> int -> 'a -> 'b) -> 'b t
