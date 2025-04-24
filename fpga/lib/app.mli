open Hardcaml

module I : sig
  type 'a t = {
    clock : 'a;
    reset : 'a;
    weight_source : 'a Config.Tpu.Stream.Weight_in.Source.t;
    data_source : 'a Config.Tpu.Stream.Data_in.Source.t;
    acc_dest : 'a Config.Tpu.Stream.Acc_out.Dest.t;
    gpio_o : 'a;
    switches : 'a;
  }
  [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t = {
    weight_dest : 'a Config.Tpu.Stream.Weight_in.Dest.t;
    data_dest : 'a Config.Tpu.Stream.Data_in.Dest.t;
    acc_source : 'a Config.Tpu.Stream.Acc_out.Source.t;
    gpio_i : 'a;
    leds : 'a;
    hex_7segs : 'a Hex_7segs.I.t;
  }
  [@@deriving sexp_of, hardcaml]
end

val hierarchical :
  ?name:string ->
  (Scope.t -> Signal.t I.t -> Signal.t O.t) ->
  Scope.t ->
  Signal.t I.t ->
  Signal.t O.t
