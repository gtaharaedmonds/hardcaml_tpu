open Base
open! Hardcaml

module type Config = sig
  val data_bits : int
  val weight_bits : int
  val acc_bits : int
  val size : int
end

module type S = sig
  module Config : Config
  module Data_matrix : Matrix.S
  module Weight_matrix : Matrix.S
  module Acc_matrix : Matrix.S

  module I : sig
    type 'a t = {
      clock : 'a;
      reset : 'a;
      clear_accs : 'a;
      start : 'a;
      weight_in : 'a Weight_matrix.t;
      data_in : 'a Data_matrix.t;
    }
    [@@deriving sexp_of, hardcaml]
  end

  module O : sig
    type 'a t = { acc_out : 'a Acc_matrix.t; ready : 'a; finished : 'a }
    [@@deriving sexp_of, hardcaml]
  end

  val create : Signal.t I.t -> Signal.t O.t
end

module type Systolic_array = sig
  module type S = S

  module Make (Config : Config) : S
end
