open! Base
open! Hardcaml
open! Hardcaml_waveterm
include Systolic_array_intf

module Make (Config : Config) = struct
  module Config = Config
  open Config

  module Generic_matrix = Matrix.Make (struct
    (* this is never instantiated as a Signal.t matrix, so bits is irrelevant *)
    let bits = -1
    let size = size
  end)

  module Data_matrix = Matrix.Make (struct
    let bits = data_bits
    let size = size
  end)

  module Weight_matrix = Matrix.Make (struct
    let bits = weight_bits
    let size = size
  end)

  module Acc_matrix = Matrix.Make (struct
    let bits = acc_bits
    let size = size
  end)

  module Mac_cell = Mac_cell.Make (struct
    let data_bits = data_bits
    let weight_bits = weight_bits
    let acc_bits = acc_bits
  end)

  module Data_wavefront = Triangular_wavefront.Make (Data_matrix)
  module Weight_wavefront = Triangular_wavefront.Make (Weight_matrix)

  module I = struct
    type 'a t = {
      clock : 'a;
      reset : 'a;
      clear_accs : 'a;
      start : 'a;
      ack_out : 'a;
      weight_in : 'a Weight_matrix.t; [@rtlprefix "weight_in_"]
      data_in : 'a Data_matrix.t; [@rtlprefix "data_in_"]
    }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      acc_out : 'a Acc_matrix.t; [@rtlprefix "acc_out_"]
      ready : 'a;
      finished : 'a;
    }
    [@@deriving sexp_of, hardcaml]
  end

  module States = struct
    type t = Ready | Running | Finished
    [@@deriving sexp_of, compare, enumerate]
  end

  let create_sm (i : _ I.t) =
    let open Signal in
    let reg_spec =
      Reg_spec.create ~clock:i.clock ~reset:i.reset ~clear:i.clear_accs ()
    in
    let max_count = (3 * size) - 3 in
    let count =
      Always.Variable.reg ~width:(Int.ceil_log2 (max_count + 1)) reg_spec
    in
    let ready = Always.Variable.wire ~default:gnd in
    let finished = Always.Variable.wire ~default:gnd in
    let sm = Always.State_machine.create (module States) reg_spec in
    Always.(
      compile
        [
          sm.switch
            [
              ( States.Ready,
                [
                  ready <--. 1;
                  when_ i.start [ count <--. 0; sm.set_next States.Running ];
                ] );
              ( States.Running,
                [
                  count <-- count.value +:. 1;
                  when_
                    (count.value ==:. max_count)
                    [ sm.set_next States.Finished ];
                ] );
              ( States.Finished,
                [
                  finished <--. 1; when_ i.ack_out [ sm.set_next States.Ready ];
                ] );
            ];
        ]);
    (ready.value, finished.value)

  let create (i : _ I.t) =
    let open Signal in
    let ready, finished = create_sm i in
    let data_wavefront =
      Data_wavefront.create ~transpose:true
        {
          Data_wavefront.I.clock = i.clock;
          reset = i.reset;
          load = i.start;
          data = i.data_in;
        }
    in
    let weight_wavefront =
      Weight_wavefront.create ~transpose:false
        {
          Weight_wavefront.I.clock = i.clock;
          reset = i.reset;
          load = i.start;
          data = i.weight_in;
        }
    in
    let cell_ins =
      Generic_matrix.create ~f:(fun _ _ ->
          {
            Mac_cell.I.clock = i.clock;
            reset = i.reset;
            clear_accs = i.clear_accs;
            weight_in = wire weight_bits;
            data_in = wire data_bits;
          })
    in
    let cell_outs =
      Generic_matrix.mapi cell_ins ~f:(fun _ _ cell_in ->
          Mac_cell.create cell_in)
    in
    Generic_matrix.iteri cell_ins ~f:(fun row col cell_in ->
        (* connect cell data outputs to adjacent data inputs *)
        cell_in.data_in
        <==
        if row = 0 then List.nth_exn data_wavefront.wavefront col
        else (Generic_matrix.get cell_outs ~row:(row - 1) ~col).data_out;

        (* connect cell weight outputs to adjacent weight inputs *)
        cell_in.weight_in
        <==
        if col = 0 then List.nth_exn weight_wavefront.wavefront row
        else (Generic_matrix.get cell_outs ~row ~col:(col - 1)).weight_out);
    {
      O.acc_out =
        Acc_matrix.create ~f:(fun row col ->
            (Generic_matrix.get cell_outs ~row ~col).acc_out);
      finished;
      ready;
    }
end

let%expect_test "systolic_array_testbench" =
  let open Make (struct
    let data_bits = 8
    let weight_bits = 8
    let acc_bits = 32
    let size = 2
  end) in
  let open Config in
  let module Sim = Cyclesim.With_interface (I) (O) in
  let sim = Sim.create create in
  let waves, sim = Waveform.create sim in
  let i = Cyclesim.inputs sim in
  let cycle () = Cyclesim.cycle sim in
  let assign_data ~f =
    Data_matrix.iteri i.data_in ~f:(fun row col d ->
        d := Bits.of_int ~width:data_bits (f row col))
  in
  let assign_weight ~f =
    Weight_matrix.iteri i.weight_in ~f:(fun row col d ->
        d := Bits.of_int ~width:data_bits (f row col))
  in
  cycle ();
  assign_data ~f:(fun row col -> (row * size) + col + 1);
  assign_weight ~f:(fun row col -> (row * size) + col + 1);
  cycle ();
  i.start := Bits.vdd;
  cycle ();
  i.start := Bits.gnd;
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  i.ack_out := Bits.vdd;
  cycle ();
  i.ack_out := Bits.gnd;
  cycle ();
  cycle ();
  Waveform.print waves ~wave_width:4 ~display_width:150 ~display_height:50
    ~signals_width:25;
  [%expect
    {|
    ┌Signals────────────────┐┌Waves──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
    │clock                  ││┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌──│
    │                       ││     └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘  │
    │reset                  ││                                                                                                                           │
    │                       ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │ack_out                ││                                                                                          ┌─────────┐                      │
    │                       ││──────────────────────────────────────────────────────────────────────────────────────────┘         └───────────────────   │
    │clear_accs             ││                                                                                                                           │
    │                       ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │                       ││──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │data_in_elements00     ││ 00       │01                                                                                                              │
    │                       ││──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │                       ││──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │data_in_elements01     ││ 00       │03                                                                                                              │
    │                       ││──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │                       ││──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │data_in_elements10     ││ 00       │02                                                                                                              │
    │                       ││──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │                       ││──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │data_in_elements11     ││ 00       │04                                                                                                              │
    │                       ││──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │start                  ││                    ┌─────────┐                                                                                            │
    │                       ││────────────────────┘         └─────────────────────────────────────────────────────────────────────────────────────────   │
    │                       ││──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │weight_in_elements00   ││ 00       │01                                                                                                              │
    │                       ││──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │                       ││──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │weight_in_elements01   ││ 00       │03                                                                                                              │
    │                       ││──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │                       ││──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │weight_in_elements10   ││ 00       │02                                                                                                              │
    │                       ││──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │                       ││──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │weight_in_elements11   ││ 00       │04                                                                                                              │
    │                       ││──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────   │
    │                       ││────────────────────────────────────────┬─────────┬─────────────────────────────────────────────────────────────────────   │
    │acc_out_elements00     ││ 00000000                               │00000001 │00000007                                                                │
    │                       ││────────────────────────────────────────┴─────────┴─────────────────────────────────────────────────────────────────────   │
    │                       ││──────────────────────────────────────────────────┬─────────┬───────────────────────────────────────────────────────────   │
    │acc_out_elements01     ││ 00000000                                         │00000003 │0000000F                                                      │
    │                       ││──────────────────────────────────────────────────┴─────────┴───────────────────────────────────────────────────────────   │
    │                       ││──────────────────────────────────────────────────┬─────────┬───────────────────────────────────────────────────────────   │
    │acc_out_elements10     ││ 00000000                                         │00000002 │0000000A                                                      │
    │                       ││──────────────────────────────────────────────────┴─────────┴───────────────────────────────────────────────────────────   │
    │                       ││────────────────────────────────────────────────────────────┬─────────┬─────────────────────────────────────────────────   │
    │acc_out_elements11     ││ 00000000                                                   │00000006 │00000016                                            │
    │                       ││────────────────────────────────────────────────────────────┴─────────┴─────────────────────────────────────────────────   │
    │finished               ││                                                                      ┌─────────────────────────────┐                      │
    │                       ││──────────────────────────────────────────────────────────────────────┘                             └───────────────────   │
    └───────────────────────┘└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
|}]
