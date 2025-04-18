open Base
open Hardcaml
open Hardcaml_waveterm
include Triangular_wavefront_intf

module Make (Matrix : Matrix.S) = struct
  module Matrix = Matrix

  let bits = Matrix.Config.bits
  let size = Matrix.Config.size

  module I = struct
    type 'a t = { clock : 'a; reset : 'a; load : 'a; data : 'a Matrix.t }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = { wavefront : 'a list [@bits bits] [@length size] }
    [@@deriving hardcaml]
  end

  let create ~transpose (i : _ I.t) =
    let open Signal in
    let reg_spec = Reg_spec.create ~reset:i.reset ~clock:i.clock () in
    let stages =
      Array.init size ~f:(fun _ ->
          Array.init size ~f:(fun _ ->
              let reg_in = wire bits in
              (reg_in, reg reg_spec reg_in)))
    in
    Array.iteri stages ~f:(fun row row_stages ->
        Array.iteri row_stages ~f:(fun col (stage_in, _) ->
            let prev_stage_out =
              if col = 0 then zero bits
              else
                let _, prev_stage_out = stages.(row).(col - 1) in
                prev_stage_out
            in
            (* loaded input needs to be x-flipped *)
            let col_flipped = size - col - 1 in
            let load_input =
              if transpose then Matrix.get i.data ~row:col_flipped ~col:row
              else Matrix.get i.data ~row ~col:col_flipped
            in
            let next = mux2 i.load load_input prev_stage_out in
            stage_in <== next));
    let wavefront =
      Array.mapi stages ~f:(fun row row_stages ->
          let _, last_out = row_stages.(size - 1) in
          pipeline reg_spec ~n:row last_out)
      |> Array.to_list
    in
    { O.wavefront }
end

let testbench () =
  let open Make (Matrix.Make (struct
    let bits = 8
    let size = 3
  end)) in
  let module Sim = Cyclesim.With_interface (I) (O) in
  let sim = Sim.create (create ~transpose:false) in
  let waves, sim = Waveform.create sim in
  let i = Cyclesim.inputs sim in
  let cycle () = Cyclesim.cycle sim in
  i.load := Bits.vdd;
  Matrix.iteri i.data ~f:(fun row col elem ->
      elem := Bits.of_int ~width:bits ((row * size) + col + 1));
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
    │wavefront0        ││ 00     │01     │02     │03     │00                       │
    │                  ││────────┴───────┴───────┴───────┴───────────────────────  │
    │                  ││────────────────┬───────┬───────┬───────┬───────────────  │
    │wavefront1        ││ 00             │04     │05     │06     │00               │
    │                  ││────────────────┴───────┴───────┴───────┴───────────────  │
    │                  ││────────────────────────┬───────┬───────┬───────┬───────  │
    │wavefront2        ││ 00                     │07     │08     │09     │00       │
    │                  ││────────────────────────┴───────┴───────┴───────┴───────  │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    └──────────────────┘└──────────────────────────────────────────────────────────┘
|}]
