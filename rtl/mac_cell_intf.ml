open Base
open! Hardcaml

(* output-stationary systolic array multiply-accumulate unit *)

module type Config = sig
  val data_bits : int
  val weight_bits : int
  val acc_bits : int
end

module type S = sig
  module Config : Config

  module I : sig
    type 'a t = {
      reset : 'a;
      clock : 'a;
      clear_accs : 'a;
      weight_in : 'a;
      data_in : 'a;
    }
    [@@deriving sexp_of, hardcaml]
  end

  module O : sig
    type 'a t = { weight_out : 'a; data_out : 'a; acc_out : 'a }
    [@@deriving sexp_of, hardcaml]
  end

  val create :
    ?name:string ->
    ?hierarchical:bool ->
    Scope.t ->
    Signal.t I.t ->
    Signal.t O.t
end

module type Mac_cell = sig
  module type S = S

  module Make (Config : Config) : S
end
