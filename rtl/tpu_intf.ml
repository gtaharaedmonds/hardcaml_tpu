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
  module Config : Config
  module Systolic_array : Systolic_array.S

  module Stream : sig
    module Weight_in : Stream.S
    module Data_in : Stream.S
    module Acc_out : Stream.S
  end

  module I : sig
    type 'a t = {
      reset : 'a;
      clock : 'a;
      clear_accs : 'a;
      start : 'a;
      weight_source : 'a Stream.Weight_in.Source.t;
          [@rtlprefix "weight_source_"]
      data_source : 'a Stream.Data_in.Source.t; [@rtlprefix "data_source_"]
      acc_dest : 'a Stream.Acc_out.Dest.t; [@rtlprefix "acc_dest_"]
    }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t = {
      ready : 'a;
      finished : 'a;
      weight_dest : 'a Stream.Weight_in.Dest.t; [@rtlprefix "weight_dest_"]
      data_dest : 'a Stream.Data_in.Dest.t; [@rtlprefix "data_dest_"]
      acc_source : 'a Stream.Acc_out.Source.t; [@rtlprefix "acc_source_"]
      debug_weight_in : 'a Systolic_array.Weight_matrix.t;
      debug_data_in : 'a Systolic_array.Data_matrix.t;
      debug_acc_out : 'a Systolic_array.Acc_matrix.t;
    }
    [@@deriving hardcaml]
  end

  val create : Signal.t I.t -> Signal.t O.t
end

module type Tpu = sig
  module type S = S

  module Stream = Stream
  module Make (Config : Config) : S
end
