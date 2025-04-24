open! Base
open Hardcaml

module I = struct
  type 'a t = {
    clock : 'a;
    reset : 'a;
    weight_source : 'a Config.Tpu.Stream.Weight_in.Source.t;
        [@rtlprefix "weight_source_"]
    data_source : 'a Config.Tpu.Stream.Data_in.Source.t;
        [@rtlprefix "data_source_"]
    acc_dest : 'a Config.Tpu.Stream.Acc_out.Dest.t; [@rtlprefix "acc_dest_"]
    gpio_o : 'a; [@bits 8]
    switches : 'a; [@bits 8]
  }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = {
    weight_dest : 'a Config.Tpu.Stream.Weight_in.Dest.t;
        [@rtlprefix "weight_dest_"]
    data_dest : 'a Config.Tpu.Stream.Data_in.Dest.t; [@rtlprefix "data_dest_"]
    acc_source : 'a Config.Tpu.Stream.Acc_out.Source.t;
        [@rtlprefix "acc_source_"]
    gpio_i : 'a; [@bits 8]
    leds : 'a; [@bits 8]
    hex_7segs : 'a Hex_7segs.I.t; [@rtlprefix "hex_7segs_"]
  }
  [@@deriving sexp_of, hardcaml]
end

let hierarchical ?(name = "app") create_fn scope input =
  let module Hierarchy = Hierarchy.In_scope (I) (O) in
  let output = Hierarchy.hierarchical ~name ~scope create_fn input in
  output
