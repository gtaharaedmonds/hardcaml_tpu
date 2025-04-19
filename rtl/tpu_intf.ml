open! Base
open! Hardcaml

module type Config = sig
  module Axi_stream_config : Axi_stream_intf.Config
  module Systolic_array_config : Systolic_array_intf.Config
end

module type S = sig
  module Axi_stream : Axi_stream.S
  module Systolic_array : Systolic_array.S
  (* 
  module I : sig
    type 'a t = {
      reset : 'a;
      clock : 'a;
      clear_accs : 'a;
      start : 'a;
      data_source : 'a Axi_stream.Source.t; [@rtlprefix "data_source_"]
      acc_dest : 'a Axi_stream.Dest.t; [@rtlprefix "acc_dest_"]
      weight_source : 'a Axi_stream.Source.t; [@rtlprefix "weight_source_"]
    }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t = {
      ready : 'a;
      finished : 'a;
      weight_dest : 'a Axi_stream.Dest.t;
      data_dest : 'a Axi_stream.Dest.t;
      acc_source : 'a Axi_stream.Source.t;
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
