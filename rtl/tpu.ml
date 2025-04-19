open Base
open! Hardcaml
open! Hardcaml_waveterm
include Tpu_intf

module Make (Config : Config) = struct
  module Config = Config
  open Config

  module Systolic_array = Systolic_array.Make (struct
    let data_bits = data_bits
    let weight_bits = weight_bits
    let acc_bits = acc_bits
    let size = size
  end)

  module Stream = struct
    module Data_in = Stream.Make (struct
      let bits = Config.data_stream_bits
    end)

    module Weight_in = Stream.Make (struct
      let bits = Config.weight_stream_bits
    end)

    module Acc_out = Stream.Make (struct
      let bits = Config.acc_stream_bits
    end)

    module Data_matrix = Stream.Make (struct
      let bits = Systolic_array.Data_matrix.sum_of_port_widths
    end)

    module Weight_matrix = Stream.Make (struct
      let bits = Systolic_array.Weight_matrix.sum_of_port_widths
    end)

    module Acc_matrix = Stream.Make (struct
      let bits = Systolic_array.Acc_matrix.sum_of_port_widths
    end)

    module Data_adapter = Stream.Adapter.Make (Data_in) (Data_matrix)
    module Weight_adapter = Stream.Adapter.Make (Weight_in) (Weight_matrix)
    module Acc_adapter = Stream.Adapter.Make (Acc_matrix) (Acc_out)
  end

  module I = struct
    type 'a t = {
      reset : 'a;
      clock : 'a;
      clear_accs : 'a;
      start : 'a;
      data_source : 'a Stream.Data_in.Source.t; [@rtlprefix "data_source_"]
      acc_dest : 'a Stream.Acc_out.Dest.t; [@rtlprefix "acc_dest_"]
      weight_source : 'a Stream.Weight_in.Source.t; [@rtlprefix "weight_source_"]
    }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = {
      ready : 'a;
      finished : 'a;
      weight_dest : 'a Stream.Weight_in.Dest.t; [@rtlprefix "weight_dest_"]
      data_dest : 'a Stream.Data_in.Dest.t; [@rtlprefix "data_dest_"]
      acc_source : 'a Stream.Acc_out.Source.t; [@rtlprefix "acc_source_"]
    }
    [@@deriving hardcaml]
  end

  let create (i : _ I.t) =
    let weight_slave_dest = Stream.Weight_matrix.Dest.Of_signal.wires () in
    let data_slave_dest = Stream.Data_matrix.Dest.Of_signal.wires () in
    let weight_adapter =
      Stream.Weight_adapter.create
        {
          Stream.Weight_adapter.I.clock = i.clock;
          reset = i.reset;
          master_source = i.weight_source;
          slave_dest = weight_slave_dest;
        }
    in
    let data_adapter =
      Stream.Data_adapter.create
        {
          Stream.Data_adapter.I.clock = i.clock;
          reset = i.reset;
          master_source = i.data_source;
          slave_dest = data_slave_dest;
        }
    in
    let weight_in =
      Systolic_array.Weight_matrix.Of_signal.unpack
        weight_adapter.slave_source.tdata
    in
    let data_in =
      Systolic_array.Data_matrix.Of_signal.unpack
        data_adapter.slave_source.tdata
    in
    let systolic_array =
      Systolic_array.create
        {
          Systolic_array.I.clock = i.clock;
          reset = i.reset;
          clear_accs = i.clear_accs;
          ack_out = i.acc_dest.tready;
          start = i.start;
          weight_in;
          data_in;
        }
    in
    Stream.Weight_matrix.Dest.Of_signal.assign weight_slave_dest
      { Stream.Weight_matrix.Dest.tready = systolic_array.ready };
    Stream.Data_matrix.Dest.Of_signal.assign data_slave_dest
      { Stream.Data_matrix.Dest.tready = systolic_array.ready };
    let acc_adapter =
      Stream.Acc_adapter.create
        {
          Stream.Acc_adapter.I.clock = i.clock;
          reset = i.reset;
          master_source =
            {
              Stream.Acc_matrix.Source.tdata =
                Systolic_array.Acc_matrix.Of_signal.pack systolic_array.acc_out;
              tvalid = systolic_array.finished;
            };
          slave_dest = { Stream.Acc_out.Dest.tready = i.acc_dest.tready };
        }
    in
    {
      O.data_dest = data_adapter.master_dest;
      weight_dest = weight_adapter.master_dest;
      acc_source = acc_adapter.slave_source;
      ready = systolic_array.ready;
      finished = systolic_array.finished;
    }
end

module Test = struct
  module Tpu = Make (struct
    let data_bits = 8
    let weight_bits = 8
    let acc_bits = 32
    let size = 2
    let data_stream_bits = 8
    let weight_stream_bits = 8
    let acc_stream_bits = 32
  end)

  module Sim = Cyclesim.With_interface (Tpu.I) (Tpu.O)

  let send_data (sim : Sim.t) ~f =
    let i = Cyclesim.inputs sim in
    let o = Cyclesim.outputs sim in
    Tpu.Stream.Data_in.Test.send sim i.data_source o.data_dest
      (Tpu.Systolic_array.Data_matrix.create ~f:(fun row col ->
           Bits.of_int ~width:Tpu.Config.data_bits (f row col))
      |> Tpu.Systolic_array.Data_matrix.Of_bits.pack)

  let send_weight (sim : Sim.t) ~f =
    let i = Cyclesim.inputs sim in
    let o = Cyclesim.outputs sim in
    Tpu.Stream.Weight_in.Test.send sim i.weight_source o.weight_dest
      (Tpu.Systolic_array.Weight_matrix.create ~f:(fun row col ->
           Bits.of_int ~width:Tpu.Config.weight_bits (f row col))
      |> Tpu.Systolic_array.Weight_matrix.Of_bits.pack)

  let%expect_test "tpu_multiply_test" =
    let open! Tpu.Systolic_array.Config in
    let sim = Sim.create Tpu.create in
    let i = Cyclesim.inputs sim in
    let o = Cyclesim.outputs sim in
    let cycle () = Cyclesim.cycle sim in
    cycle ();
    send_data sim ~f:(fun row col -> (row * Tpu.Config.size) + col + 1);
    send_weight sim ~f:(fun row col -> (row * Tpu.Config.size) + col + 1);
    cycle ();
    i.start := Bits.vdd;
    cycle ();
    i.start := Bits.gnd;
    cycle ();
    let result =
      Tpu.Stream.Acc_out.Test.receive sim o.acc_source i.acc_dest
        ~len:Tpu.Systolic_array.Acc_matrix.sum_of_port_widths
      |> Tpu.Systolic_array.Acc_matrix.Of_bits.unpack
    in
    Tpu.Systolic_array.Acc_matrix.pp result (fun value ->
        Bits.to_int value |> Int.to_string);
    [%expect
      {|
      ┌─-------─┐
      │ 7  │ 10 │
      │ 15 │ 22 │
      └─-------─┘
      |}]

  let%expect_test "tpu_testbench" =
    let open! Tpu.Systolic_array.Config in
    let sim = Sim.create Tpu.create in
    let waves, sim = Waveform.create sim in
    let i = Cyclesim.inputs sim in
    let cycle () = Cyclesim.cycle sim in
    cycle ();
    send_data sim ~f:(fun row col -> (row * Tpu.Config.size) + col + 1);
    send_weight sim ~f:(fun row col -> (row * Tpu.Config.size) + col + 1);
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
    cycle ();
    i.acc_dest.tready := Bits.vdd;
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    Waveform.print waves ~wave_width:4 ~display_width:290 ~display_height:40
      ~signals_width:30;
    [%expect
      {|
      ┌Signals─────────────────────┐┌Waves─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
      │clock                       ││┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐  │
      │                            ││     └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └──│
      │reset                       ││                                                                                                                                                                                                                                                                  │
      │                            ││──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │acc_dest_tready             ││                                                                                                                                                                                                        ┌─────────────────────────────────────────────────────────│
      │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘                                                         │
      │clear_accs                  ││                                                                                                                                                                                                                                                                  │
      │                            ││──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │                            ││──────────┬─────────┬─────────┬─────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │data_source_tdata           ││ 00       │01       │02       │03       │04                                                                                                                                                                                                                       │
      │                            ││──────────┴─────────┴─────────┴─────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │data_source_tvalid          ││          ┌───────────────────────────────────────┐                                                                                                                                                                                                               │
      │                            ││──────────┘                                       └───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │start                       ││                                                                                                                        ┌─────────┐                                                                                                                               │
      │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘         └───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │                            ││────────────────────────────────────────────────────────────┬─────────┬─────────┬─────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │weight_source_tdata         ││ 00                                                         │01       │02       │03       │04                                                                                                                                                                     │
      │                            ││────────────────────────────────────────────────────────────┴─────────┴─────────┴─────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │weight_source_tvalid        ││                                                            ┌───────────────────────────────────────┐                                                                                                                                                             │
      │                            ││────────────────────────────────────────────────────────────┘                                       └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬─────────────────────────────┬─────────┬─────────┬─────────┬─────────────────│
      │acc_source_tdata            ││ 00000000                                                                                                                                                                           │00000016                     │0000000F │0000000A │00000007 │00000000         │
      │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴─────────────────────────────┴─────────┴─────────┴─────────┴─────────────────│
      │acc_source_tvalid           ││                                                                                                                                                                                    ┌───────────────────────────────────────────────────────────┐                 │
      │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘                                                           └─────────────────│
      │data_dest_tready            ││──────────────────────────────────────────────────┐         ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │                            ││                                                  └─────────┘                                                                                                                                                                                                     │
      │finished                    ││                                                                                                                                                                          ┌───────────────────────────────────────┐                                               │
      │                            ││──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘                                       └───────────────────────────────────────────────│
      │ready                       ││──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐                                                                               ┌───────────────────────────────────────────────│
      │                            ││                                                                                                                                  └───────────────────────────────────────────────────────────────────────────────┘                                               │
      │weight_dest_tready          ││────────────────────────────────────────────────────────────────────────────────────────────────────┐         ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────│
      │                            ││                                                                                                    └─────────┘                                                                                                                                                   │
      │                            ││                                                                                                                                                                                                                                                                  │
      │                            ││                                                                                                                                                                                                                                                                  │
      │                            ││                                                                                                                                                                                                                                                                  │
      │                            ││                                                                                                                                                                                                                                                                  │
      │                            ││                                                                                                                                                                                                                                                                  │
      └────────────────────────────┘└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘|}]
end
