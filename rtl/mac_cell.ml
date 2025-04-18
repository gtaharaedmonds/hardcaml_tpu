open! Base
open! Hardcaml
open! Hardcaml_waveterm
include Mac_cell_intf

module Make (Config : Config) = struct
  module Config = Config
  open Config

  module I = struct
    type 'a t = {
      reset : 'a;
      clock : 'a;
      clear : 'a;
      weight_in : 'a; [@bits weight_bits]
      data_in : 'a; [@bits data_bits]
    }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      weight_out : 'a; [@bits weight_bits]
      data_out : 'a; [@bits data_bits]
      acc_out : 'a; [@bits acc_bits]
    }
    [@@deriving sexp_of, hardcaml]
  end

  let create (i : _ I.t) =
    let open Signal in
    let reg_async = Reg_spec.create ~reset:i.reset ~clock:i.clock () in
    let weight_buf = Always.Variable.reg ~width:weight_bits reg_async in
    let data_buf = Always.Variable.reg ~width:data_bits reg_async in
    let acc_buf = Always.Variable.reg ~width:acc_bits reg_async in
    Always.(
      compile
        [
          if_ i.clear
            [
              weight_buf <-- of_int ~width:weight_bits 0;
              data_buf <-- of_int ~width:data_bits 0;
              acc_buf <-- of_int ~width:acc_bits 0;
            ]
            [
              weight_buf <-- i.weight_in;
              data_buf <-- i.data_in;
              (let weight_ext =
                 concat_lsb
                   [ i.weight_in; of_int ~width:(acc_bits - weight_bits) 0 ]
               in
               let data_ext =
                 concat_lsb
                   [ i.data_in; of_int ~width:(acc_bits - data_bits) 0 ]
               in
               acc_buf
               <-- (weight_ext *: data_ext).:[acc_bits - 1, 0] +: acc_buf.value);
            ];
        ]);
    {
      O.weight_out = weight_buf.value;
      data_out = data_buf.value;
      acc_out = acc_buf.value;
    }
end

let testbench () =
  let module Mac_cell_test = Make (struct
    let data_bits = 8
    let weight_bits = 8
    let acc_bits = 32
  end) in
  let open Mac_cell_test.Config in
  let module Sim = Cyclesim.With_interface (Mac_cell_test.I) (Mac_cell_test.O)
  in
  let sim = Sim.create Mac_cell_test.create in
  let waves, sim = Waveform.create sim in
  let i = Cyclesim.inputs sim in
  let cycle () = Cyclesim.cycle sim in
  cycle ();
  i.data_in := Bits.of_int ~width:data_bits 0x8;
  i.weight_in := Bits.of_int ~width:weight_bits 0x9;
  cycle ();
  i.data_in := Bits.of_int ~width:data_bits 0x3;
  i.weight_in := Bits.of_int ~width:weight_bits 0x4;
  cycle ();
  i.data_in := Bits.of_int ~width:data_bits 0;
  i.weight_in := Bits.of_int ~width:weight_bits 0;
  cycle ();
  cycle ();
  i.clear := Bits.vdd;
  cycle ();
  i.clear := Bits.gnd;
  cycle ();
  i.data_in := Bits.of_int ~width:data_bits 0x52;
  i.weight_in := Bits.of_int ~width:weight_bits 0x68;
  cycle ();
  cycle ();
  waves

let%expect_test "mac_cell_testbench" =
  let waves = testbench () in
  Waveform.print waves ~wave_width:4 ~display_width:120 ~display_height:25;
  [%expect
    {|
    ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────────────────────────────────────────────┐
    │clock             ││┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐  │
    │                  ││     └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └──│
    │reset             ││                                                                                                  │
    │                  ││──────────────────────────────────────────────────────────────────────────────────────────        │
    │clear             ││                                                  ┌─────────┐                                     │
    │                  ││──────────────────────────────────────────────────┘         └─────────────────────────────        │
    │                  ││──────────┬─────────┬─────────┬───────────────────────────────────────┬───────────────────        │
    │data_in           ││ 00       │08       │03       │00                                     │52                         │
    │                  ││──────────┴─────────┴─────────┴───────────────────────────────────────┴───────────────────        │
    │                  ││──────────┬─────────┬─────────┬───────────────────────────────────────┬───────────────────        │
    │weight_in         ││ 00       │09       │04       │00                                     │68                         │
    │                  ││──────────┴─────────┴─────────┴───────────────────────────────────────┴───────────────────        │
    │                  ││────────────────────┬─────────┬─────────────────────────────┬───────────────────┬─────────        │
    │acc_out           ││ 00000000           │00000048 │00000054                     │00000000           │00002150         │
    │                  ││────────────────────┴─────────┴─────────────────────────────┴───────────────────┴─────────        │
    │                  ││────────────────────┬─────────┬─────────┬───────────────────────────────────────┬─────────        │
    │data_out          ││ 00                 │08       │03       │00                                     │52               │
    │                  ││────────────────────┴─────────┴─────────┴───────────────────────────────────────┴─────────        │
    │                  ││────────────────────┬─────────┬─────────┬───────────────────────────────────────┬─────────        │
    │weight_out        ││ 00                 │09       │04       │00                                     │68               │
    │                  ││────────────────────┴─────────┴─────────┴───────────────────────────────────────┴─────────        │
    │                  ││                                                                                                  │
    │                  ││                                                                                                  │
    └──────────────────┘└──────────────────────────────────────────────────────────────────────────────────────────────────┘
  |}]
