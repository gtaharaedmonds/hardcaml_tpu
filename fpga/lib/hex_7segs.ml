open Base
open Hardcaml
open Hardcaml_waveterm
open Signal

let num_7segs = 8

module I = struct
  type 'a t = {
    clock : 'a;
    reset : 'a;
    enables : 'a list; [@length num_7segs]
    values : 'a list; [@bits Int.ceil_log2 16] [@length num_7segs]
  }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = {
    anodes : 'a list; [@length num_7segs]
    cathodes : 'a; [@bits 7]
    decimal_point : 'a;
  }
  [@@deriving sexp_of, hardcaml]
end

let wrapping_counter reg_spec max =
  reg_fb reg_spec ~width:(Int.ceil_log2 max) ~f:(fun count ->
      mux2 (count ==:. max - 1) (zero (width count)) (count +:. 1))

let create_single_hex_7seg enable value =
  mux2 enable
    (mux value
       (List.map ~f:of_bit_string
          [
            "1000000" (* 0 *);
            "1111001" (* 1 *);
            "0100100" (* 2 *);
            "0110000" (* 3 *);
            "0011001" (* 4 *);
            "0010010" (* 5 *);
            "0000010" (* 6 *);
            "1111000" (* 7 *);
            "0000000" (* 8 *);
            "0010000" (* 9 *);
            "0001000" (* A *);
            "0000011" (* B *);
            "1000110" (* C *);
            "0100001" (* D *);
            "0000110" (* E *);
            "0001110" (* F *);
          ]))
    (ones 7)

let create _scope (i : _ I.t) =
  let reg_spec = Reg_spec.create ~clock:i.clock ~reset:i.reset () in
  let active_7seg = wrapping_counter reg_spec num_7segs in
  {
    (* anode enables are inverted *)
    O.anodes = List.init num_7segs ~f:(fun anode -> ~:(active_7seg ==:. anode));
    cathodes =
      create_single_hex_7seg
        (mux active_7seg i.enables)
        (mux active_7seg i.values);
    decimal_point = vdd;
  }

let hierarchical ?(name = "hex_7segs") scope input =
  let module Hierarchy = Hierarchy.In_scope (I) (O) in
  let output = Hierarchy.hierarchical ~name ~scope create input in
  output

let%expect_test "mac_cell_testbench" =
  let module Sim = Cyclesim.With_interface (I) (O) in
  let sim = Sim.create (create (Scope.create ())) in
  let waves, sim = Waveform.create sim in
  let i = Cyclesim.inputs sim in
  let cycle n =
    for _ = 0 to n do
      Cyclesim.cycle sim
    done
  in
  List.iteri i.enables ~f:(fun i enable ->
      enable := if i = 3 then Bits.gnd else Bits.vdd);
  List.iteri i.values ~f:(fun i value ->
      value := Bits.of_int ~width:(Bits.width !value) i);
  cycle 100;
  cycle 100;
  cycle 100;
  cycle 100;
  cycle 100;
  cycle 100;
  cycle 100;
  Waveform.print waves ~display_height:70 ~wave_width:1;
  [%expect
    {|
    ┌Signals────────┐┌Waves──────────────────────────────────────────────┐
    │clock          ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐│
    │               ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └│
    │reset          ││                                                   │
    │               ││───────────────────────────────────────────────────│
    │enables0       ││───────────────────────────────────────────────────│
    │               ││                                                   │
    │enables1       ││───────────────────────────────────────────────────│
    │               ││                                                   │
    │enables2       ││───────────────────────────────────────────────────│
    │               ││                                                   │
    │enables3       ││                                                   │
    │               ││───────────────────────────────────────────────────│
    │enables4       ││───────────────────────────────────────────────────│
    │               ││                                                   │
    │enables5       ││───────────────────────────────────────────────────│
    │               ││                                                   │
    │enables6       ││───────────────────────────────────────────────────│
    │               ││                                                   │
    │enables7       ││───────────────────────────────────────────────────│
    │               ││                                                   │
    │               ││───────────────────────────────────────────────────│
    │values0        ││ 0                                                 │
    │               ││───────────────────────────────────────────────────│
    │               ││───────────────────────────────────────────────────│
    │values1        ││ 1                                                 │
    │               ││───────────────────────────────────────────────────│
    │               ││───────────────────────────────────────────────────│
    │values2        ││ 2                                                 │
    │               ││───────────────────────────────────────────────────│
    │               ││───────────────────────────────────────────────────│
    │values3        ││ 3                                                 │
    │               ││───────────────────────────────────────────────────│
    │               ││───────────────────────────────────────────────────│
    │values4        ││ 4                                                 │
    │               ││───────────────────────────────────────────────────│
    │               ││───────────────────────────────────────────────────│
    │values5        ││ 5                                                 │
    │               ││───────────────────────────────────────────────────│
    │               ││───────────────────────────────────────────────────│
    │values6        ││ 6                                                 │
    │               ││───────────────────────────────────────────────────│
    │               ││───────────────────────────────────────────────────│
    │values7        ││ 7                                                 │
    │               ││───────────────────────────────────────────────────│
    │anodes0        ││    ┌───────────────────────────┐   ┌──────────────│
    │               ││────┘                           └───┘              │
    │anodes1        ││────┐   ┌───────────────────────────┐   ┌──────────│
    │               ││    └───┘                           └───┘          │
    │anodes2        ││────────┐   ┌───────────────────────────┐   ┌──────│
    │               ││        └───┘                           └───┘      │
    │anodes3        ││────────────┐   ┌───────────────────────────┐   ┌──│
    │               ││            └───┘                           └───┘  │
    │anodes4        ││────────────────┐   ┌───────────────────────────┐  │
    │               ││                └───┘                           └──│
    │anodes5        ││────────────────────┐   ┌──────────────────────────│
    │               ││                    └───┘                          │
    │anodes6        ││────────────────────────┐   ┌──────────────────────│
    │               ││                        └───┘                      │
    │anodes7        ││────────────────────────────┐   ┌──────────────────│
    │               ││                            └───┘                  │
    │               ││────┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬──│
    │cathodes       ││ 40 │79 │24 │7F │19 │12 │02 │78 │40 │79 │24 │7F │19│
    │               ││────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴──│
    │decimal_point  ││───────────────────────────────────────────────────│
    │               ││                                                   │
    │               ││                                                   │
    │               ││                                                   │
    │               ││                                                   │
    └───────────────┘└───────────────────────────────────────────────────┘
    |}]
