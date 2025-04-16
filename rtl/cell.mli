open! Base
open! Hardcaml

module I : sig
  type 'a t = {
    reset : 'a;
    clock : 'a;
    clear : 'a;
    weight_in : 'a; [@bits weight_bits]
    data_in : 'a; [@bits data_bits]
  }
  [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t = {
    weight_out : 'a; [@bits weight_bits]
    data_out : 'a; [@bits data_bits]
    acc_out : 'a; [@bits acc_bits]
  }
  [@@deriving sexp_of, hardcaml]
end

val weight_bits : int
val data_bits : int
val acc_bits : int
val create : Signal.t I.t -> Signal.t O.t
