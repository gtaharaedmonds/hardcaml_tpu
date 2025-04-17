open Base
open Hardcaml
open Hardcaml_waveterm

let size = 3
let data_bits = 8

module I = struct
  type 'a t = { clock : 'a; reset : 'a; load : 'a; input : 'a Matrix.t }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { wavefront : 'a list [@bits data_bits] [@length size] }
  [@@deriving hardcaml]
end

let create (i : _ I.t) =
  let open Signal in
  let reg_spec = Reg_spec.create ~reset:i.reset ~clock:i.clock () in
  let stages =
    Array.init size ~f:(fun _ ->
        Array.init size ~f:(fun _ ->
            let reg_in = wire data_bits in
            (reg_in, reg reg_spec reg_in)))
  in
  Array.iteri stages ~f:(fun row row_stages ->
      Array.iteri row_stages ~f:(fun col (stage_in, _) ->
          let prev_stage_out =
            if col = 0 then zero data_bits
            else
              let _, prev_stage_out = stages.(row).(col - 1) in
              prev_stage_out
          in
          let next =
            mux2 i.load (Matrix.get i.input ~row ~col) prev_stage_out
          in
          stage_in <== next));
  let wavefront =
    Array.mapi stages ~f:(fun row row_stages ->
        let _, last_out = row_stages.(size - 1) in
        pipeline reg_spec ~n:row last_out)
    |> Array.to_list
  in
  { O.wavefront }

let testbench () =
  let module Sim = Cyclesim.With_interface (I) (O) in
  let sim = Sim.create create in
  let waves, sim = Waveform.create sim in
  let i = Cyclesim.inputs sim in
  let cycle () = Cyclesim.cycle sim in
  i.load := Bits.vdd;
  Matrix.iteri i.input ~f:(fun row col elem ->
      elem := Bits.of_int ~width:data_bits ((row * size) + col + 1));
  cycle ();
  i.load := Bits.gnd;
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  waves

let%expect_test "triangular_wavefront_testbench" =
  let waves = testbench () in
  Waveform.print waves ~display_width:80 ~display_height:50;
  [%expect
    {|
  ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────┐
  │clock             ││┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌───┐   ┌─│
  │                  ││    └───┘   └───┘   └───┘   └───┘   └───┘   └───┘   └───┘ │
  │reset             ││                                                          │
  │                  ││────────────────────────────────────────────────────────  │
  │                  ││────────────────────────────────────────────────────────  │
  │elements00        ││ 01                                                       │
  │                  ││────────────────────────────────────────────────────────  │
  │                  ││────────────────────────────────────────────────────────  │
  │elements01        ││ 04                                                       │
  │                  ││────────────────────────────────────────────────────────  │
  │                  ││────────────────────────────────────────────────────────  │
  │elements02        ││ 07                                                       │
  │                  ││────────────────────────────────────────────────────────  │
  │                  ││────────────────────────────────────────────────────────  │
  │elements10        ││ 02                                                       │
  │                  ││────────────────────────────────────────────────────────  │
  │                  ││────────────────────────────────────────────────────────  │
  │elements11        ││ 05                                                       │
  │                  ││────────────────────────────────────────────────────────  │
  │                  ││────────────────────────────────────────────────────────  │
  │elements12        ││ 08                                                       │
  │                  ││────────────────────────────────────────────────────────  │
  │                  ││────────────────────────────────────────────────────────  │
  │elements20        ││ 03                                                       │
  │                  ││────────────────────────────────────────────────────────  │
  │                  ││────────────────────────────────────────────────────────  │
  │elements21        ││ 06                                                       │
  │                  ││────────────────────────────────────────────────────────  │
  │                  ││────────────────────────────────────────────────────────  │
  │elements22        ││ 09                                                       │
  │                  ││────────────────────────────────────────────────────────  │
  │load              ││────────┐                                                 │
  │                  ││        └───────────────────────────────────────────────  │
  │                  ││────────┬───────┬───────┬───────┬───────────────────────  │
  │wavefront0        ││ 00     │03     │02     │01     │00                       │
  │                  ││────────┴───────┴───────┴───────┴───────────────────────  │
  │                  ││────────────────┬───────┬───────┬───────┬───────────────  │
  │wavefront1        ││ 00             │06     │05     │04     │00               │
  │                  ││────────────────┴───────┴───────┴───────┴───────────────  │
  │                  ││────────────────────────┬───────┬───────┬───────┬───────  │
  │wavefront2        ││ 00                     │09     │08     │07     │00       │
  │                  ││────────────────────────┴───────┴───────┴───────┴───────  │
  │                  ││                                                          │
  │                  ││                                                          │
  │                  ││                                                          │
  │                  ││                                                          │
  │                  ││                                                          │
  │                  ││                                                          │
  └──────────────────┘└──────────────────────────────────────────────────────────┘
|}]
