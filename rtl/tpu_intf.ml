open! Base
open! Hardcaml

module type Config = sig
  val data_bits : int
  val weight_bits : int
  val acc_bits : int
  val size : int
  val data_stream_bits : int
  val weight_stream_bits : int
  val acc_stream_bits : int
end

module type S = sig
  (* module Stream : Stream.S *)
  (* module Systolic_array : Systolic_array.S *)
  (* 
  module I : sig
    type 'a t = {
      reset : 'a;
      clock : 'a;
      clear_accs : 'a;
      start : 'a;
      data_source : 'a Stream.Source.t; [@rtlprefix "data_source_"]
      acc_dest : 'a Stream.Dest.t; [@rtlprefix "acc_dest_"]
      weight_source : 'a Stream.Source.t; [@rtlprefix "weight_source_"]
    }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t = {
      ready : 'a;
      finished : 'a;
      weight_dest : 'a Stream.Dest.t;
      data_dest : 'a Stream.Dest.t;
      acc_source : 'a Stream.Source.t;
      acc_out : 'a Systolic_array.Acc_matrix.t;
    }
    [@@deriving hardcaml]
  end

  val create : Signal.t I.t -> Signal.t O.t *)

end

module type Tpu = sig
  module type S = S

  module Make (Config : Config) : S
end
