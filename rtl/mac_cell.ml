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
      clear_accs : 'a;
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

  let create_fn _scope (i : _ I.t) =
    let open Signal in
    let reg_async = Reg_spec.create ~reset:i.reset ~clock:i.clock () in
    let weight_out = Always.Variable.reg ~width:weight_bits reg_async in
    let data_out = Always.Variable.reg ~width:data_bits reg_async in
    let acc_out = Always.Variable.reg ~width:acc_bits reg_async in
    Always.(
      compile
        [
          if_ i.clear_accs
            [ weight_out <--. 0; data_out <--. 0; acc_out <--. 0 ]
            [
              weight_out <-- i.weight_in;
              data_out <-- i.data_in;
              (let weight_ext =
                 concat_lsb
                   [ i.weight_in; of_int ~width:(acc_bits - weight_bits) 0 ]
               in
               let data_ext =
                 concat_lsb
                   [ i.data_in; of_int ~width:(acc_bits - data_bits) 0 ]
               in
               acc_out
               <-- (weight_ext *: data_ext).:[acc_bits - 1, 0] +: acc_out.value);
            ];
        ]);
    {
      O.weight_out = weight_out.value;
      data_out = data_out.value;
      acc_out = acc_out.value;
    }

  let create ?(name = "mac_cell") ?(hierarchical = false) scope input =
    if hierarchical then
      let module Hierarchy = Hierarchy.In_scope (I) (O) in
      let output = Hierarchy.hierarchical ~name ~scope create_fn input in
      output
    else create_fn scope input
end

let%expect_test "mac_cell_testbench" =
  let open Make (struct
    let data_bits = 8
    let weight_bits = 8
    let acc_bits = 32
  end) in
  let open Config in
  let module Sim = Cyclesim.With_interface (I) (O) in
  let scope = Scope.create () in
  let sim = Sim.create (create scope) in
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
  i.clear_accs := Bits.vdd;
  cycle ();
  i.clear_accs := Bits.gnd;
  cycle ();
  i.data_in := Bits.of_int ~width:data_bits 0x52;
  i.weight_in := Bits.of_int ~width:weight_bits 0x68;
  cycle ();
  cycle ();
  Waveform.print waves ~wave_width:4 ~display_width:120 ~display_height:25;
  [%expect
    {|
    ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────────────────────────────────────────────┐
    │clock             ││┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐  │
    │                  ││     └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └──│
    │reset             ││                                                                                                  │
    │                  ││──────────────────────────────────────────────────────────────────────────────────────────        │
    │clear_accs        ││                                                  ┌─────────┐                                     │
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
