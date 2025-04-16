open! Base
open! Hardcaml
open! Hardcaml_waveterm

let size = 3

module Cell_array = struct
  type 'a cell = { i : 'a Cell.I.t; o : 'a Cell.O.t } [@@deriving sexp_of]
  type 'a t = 'a cell Array.t Array.t [@@deriving sexp_of]

  let create size (f : unit -> _ cell) =
    Array.init size ~f:(fun _ -> Array.init size ~f:(fun _ -> f ()))

  let get (t : _ t) row col =
    let row_arr = Array.get t row in
    Array.get row_arr col

  let iteri (t : _ t) f =
    Array.iteri t ~f:(fun row row_arr ->
        Array.iteri row_arr ~f:(fun col cell -> f row col cell))
end

module I = struct
  type 'a t = {
    clock : 'a;
    reset : 'a;
    clear : 'a;
    weight_in : 'a list; [@bits Cell.weight_bits] [@length size]
    data_in : 'a list; [@bits Cell.data_bits] [@length size]
  }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = { acc_out : 'a list [@bits Cell.acc_bits] [@length size] }
  [@@deriving sexp_of, hardcaml]
end

let create (i : _ I.t) =
  let open Signal in
  let cell_array =
    Cell_array.create size (fun () ->
        let i =
          {
            Cell.I.clock = i.clock;
            reset = i.reset;
            clear = i.clear;
            weight_in = wire Cell.weight_bits;
            data_in = wire Cell.data_bits;
          }
        in
        { Cell_array.i; o = Cell.create i })
  in
  let systolic_array =
    { O.acc_out = List.init size ~f:(fun _ -> wire Cell.acc_bits) }
  in
  ignore Cell_array.get;
  Cell_array.iteri cell_array (fun row col cell ->
      (* connect cell data outputs to adjacent data inputs *)
      if row = 0 then cell.i.data_in <== List.nth_exn i.data_in col
      else
        cell.i.data_in <== (Cell_array.get cell_array (row - 1) col).o.data_out;

      (* connect cell weight outputs to adjacent weight inputs *)
      if col = 0 then cell.i.weight_in <== List.nth_exn i.weight_in row
      else
        cell.i.weight_in
        <== (Cell_array.get cell_array row (col - 1)).o.weight_out;

      (* for debugging: connect last row to output accs *)
      if row = size - 1 then
        List.nth_exn systolic_array.acc_out col <== cell.o.acc_out);
  systolic_array

let testbench () =
  let module Sim = Cyclesim.With_interface (I) (O) in
  let sim = Sim.create create in
  let waves, sim = Waveform.create sim in
  let i = Cyclesim.inputs sim in
  let cycle () = Cyclesim.cycle sim in
  let assign_data lst =
    List.iter2_exn lst i.data_in ~f:(fun num d ->
        d := Bits.of_int ~width:Cell.data_bits num)
  in
  let assign_weight lst =
    List.iter2_exn lst i.weight_in ~f:(fun num w ->
        w := Bits.of_int ~width:Cell.weight_bits num)
  in
  cycle ();
  assign_data [ 0x32; 0x64; 0x128 ];
  assign_weight [ 0x2; 0x4; 0x8 ];
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  waves

let%expect_test "systolic_array_testbench" =
  let waves = testbench () in
  Waveform.print waves ~wave_width:4 ~display_width:120 ~display_height:50;
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
