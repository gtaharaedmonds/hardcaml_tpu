open Base
open! Hardcaml
open! Hardcaml_waveterm
module Stream = Stream
include Tpu_intf

module Make (Config : Config) = struct
  module Config = Config
  open Config

  module Systolic_array = Systolic_array.Make (struct
    let weight_bits = weight_bits
    let data_bits = data_bits
    let acc_bits = acc_bits
    let size = size
  end)

  module Stream = struct
    module Weight_in = Stream.Make (struct
      let bits = Config.weight_stream_bits
    end)

    module Data_in = Stream.Make (struct
      let bits = Config.data_stream_bits
    end)

    module Acc_out = Stream.Make (struct
      let bits = Config.acc_stream_bits
    end)

    module Weight_matrix = Stream.Make (struct
      let bits = Systolic_array.Weight_matrix.sum_of_port_widths
    end)

    module Data_matrix = Stream.Make (struct
      let bits = Systolic_array.Data_matrix.sum_of_port_widths
    end)

    module Acc_matrix = Stream.Make (struct
      let bits = Systolic_array.Acc_matrix.sum_of_port_widths
    end)

    module Weight_adapter = Stream.Adapter.Make (Weight_in) (Weight_matrix)
    module Data_adapter = Stream.Adapter.Make (Data_in) (Data_matrix)
    module Acc_adapter = Stream.Adapter.Make (Acc_matrix) (Acc_out)
  end

  module I = struct
    type 'a t = {
      reset : 'a;
      clock : 'a;
      clear_accs : 'a;
      start : 'a;
      weight_source : 'a Stream.Weight_in.Source.t;
          [@rtlprefix "weight_source_"]
      data_source : 'a Stream.Data_in.Source.t; [@rtlprefix "data_source_"]
      acc_dest : 'a Stream.Acc_out.Dest.t; [@rtlprefix "acc_dest_"]
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
      debug_weight_in : 'a Systolic_array.Weight_matrix.t;
          [@rtlprefix "debug_weight_in_"]
      debug_data_in : 'a Systolic_array.Data_matrix.t;
          [@rtlprefix "debug_data_in_"]
      debug_acc_out : 'a Systolic_array.Acc_matrix.t;
          [@rtlprefix "debug_acc_out_"]
    }
    [@@deriving hardcaml]
  end

  let create (i : _ I.t) =
    let open Signal in
    (* let reg_spec = Reg_spec.create ~clock:i.clock ~reset:i.reset () in *)
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
      (* Systolic_array.Weight_matrix.Of_signal.reg *)
      (* ~enable:weight_adapter.slave_source.tvalid reg_spec *)
      Systolic_array.Weight_matrix.Of_signal.unpack
        weight_adapter.slave_source.tdata
    in
    (* IMPORTANT: The weight_adapter.slave_source's tvalid signals aren't used
    here? Maybe other places I'm not being totally complaint... *)
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
              tkeep = ones (Stream.Acc_matrix.Config.bits / 8);
              tlast = gnd;
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
      debug_weight_in = weight_in;
      debug_data_in = data_in;
      debug_acc_out = systolic_array.acc_out;
    }

  module Test = struct
    module Sim = Cyclesim.With_interface (I) (O)

    module Matrix = Matrix.Make (struct
      let bits = -1
      let size = Config.size
    end)

    let send_weight (sim : Sim.t) (m : int Matrix.t) =
      let i = Cyclesim.inputs sim in
      let o = Cyclesim.outputs sim in
      Stream.Weight_in.Test.send sim i.weight_source o.weight_dest
        (Systolic_array.Weight_matrix.create ~f:(fun row col ->
             Bits.of_int ~width:Config.weight_bits (Matrix.get m ~row ~col))
        |> Systolic_array.Weight_matrix.Of_bits.pack)

    let send_data (sim : Sim.t) (m : int Matrix.t) =
      let i = Cyclesim.inputs sim in
      let o = Cyclesim.outputs sim in
      Stream.Data_in.Test.send sim i.data_source o.data_dest
        (Systolic_array.Data_matrix.create ~f:(fun row col ->
             Bits.of_int ~width:Config.data_bits (Matrix.get m ~row ~col))
        |> Systolic_array.Data_matrix.Of_bits.pack)

    let start (sim : Sim.t) =
      let i = Cyclesim.inputs sim in
      let o = Cyclesim.outputs sim in
      if Bits.is_gnd !(o.ready) then
        raise_s
          [%message "tried to start a multiplication when the TPU wasn't ready"];
      i.start := Bits.vdd;
      Cyclesim.cycle sim;
      i.start := Bits.gnd;
      Cyclesim.cycle sim

    let receive_result (sim : Sim.t) =
      let i = Cyclesim.inputs sim in
      let o = Cyclesim.outputs sim in
      Stream.Acc_out.Test.receive sim o.acc_source i.acc_dest
        ~len:Systolic_array.Acc_matrix.sum_of_port_widths
      |> Systolic_array.Acc_matrix.Of_bits.unpack
  end
end

let%expect_test "test_2x2" =
  let open Make (struct
    let weight_bits = 8
    let data_bits = 8
    let acc_bits = 32
    let size = 2
    let weight_stream_bits = 32
    let data_stream_bits = 32
    let acc_stream_bits = 32
  end) in
  let sim = Test.Sim.create create in
  Test.send_weight sim (Test.Matrix.of_list [ [ 1; 2 ]; [ 3; 4 ] ]);
  Test.send_data sim (Test.Matrix.of_list [ [ 5; 6 ]; [ 7; 8 ] ]);
  Test.start sim;
  let result = Test.receive_result sim in
  Systolic_array.Acc_matrix.pp result (fun value ->
      Bits.to_int value |> Int.to_string);
  [%expect
    {|
    ┌─-------─┐
    │ 19 │ 22 │
    │ 43 │ 50 │
    └─-------─┘
    |}]

let%expect_test "test_4x4" =
  let open Make (struct
    let weight_bits = 8
    let data_bits = 8
    let acc_bits = 32
    let size = 4
    let weight_stream_bits = 8
    let data_stream_bits = 8
    let acc_stream_bits = 32
  end) in
  let sim = Test.Sim.create create in
  Test.send_weight sim
    (Test.Matrix.of_list
       [ [ 1; 2; 3; 4 ]; [ 1; 2; 3; 4 ]; [ 1; 2; 3; 4 ]; [ 1; 2; 3; 4 ] ]);
  Test.send_data sim
    (Test.Matrix.of_list
       [ [ 5; 6; 7; 8 ]; [ 5; 6; 7; 8 ]; [ 5; 6; 7; 8 ]; [ 5; 6; 7; 8 ] ]);
  Test.start sim;
  let result = Test.receive_result sim in
  Systolic_array.Acc_matrix.pp result (fun value ->
      Bits.to_int value |> Int.to_string);
  [%expect
    {|
    ┌─-----------------─┐
    │ 50 │ 60 │ 70 │ 80 │
    │ 50 │ 60 │ 70 │ 80 │
    │ 50 │ 60 │ 70 │ 80 │
    │ 50 │ 60 │ 70 │ 80 │
    └─-----------------─┘
    |}]

let%expect_test "test_wide_streams" =
  let open Make (struct
    let weight_bits = 8
    let data_bits = 8
    let acc_bits = 32
    let size = 2
    let weight_stream_bits = 32
    let data_stream_bits = 32
    let acc_stream_bits = 128
  end) in
  let sim = Test.Sim.create create in
  Test.send_weight sim (Test.Matrix.of_list [ [ 2; 0 ]; [ 0; 2 ] ]);
  Test.send_data sim (Test.Matrix.of_list [ [ 5; 6 ]; [ 7; 8 ] ]);
  Test.start sim;
  let result = Test.receive_result sim in
  Systolic_array.Acc_matrix.pp result (fun value ->
      Bits.to_int value |> Int.to_string);
  [%expect
    {|
    ┌─-------─┐
    │ 10 │ 12 │
    │ 14 │ 16 │
    └─-------─┘
    |}]

let%expect_test "test_data_weight_different_widths" =
  let open Make (struct
    let weight_bits = 8
    let data_bits = 4
    let acc_bits = 16
    let size = 2
    let weight_stream_bits = 8
    let data_stream_bits = 8
    let acc_stream_bits = 32
  end) in
  let sim = Test.Sim.create create in
  Test.send_weight sim (Test.Matrix.of_list [ [ 1; 2 ]; [ 3; 4 ] ]);
  Test.send_data sim (Test.Matrix.of_list [ [ 2; 0 ]; [ 0; 2 ] ]);
  Test.start sim;
  let result = Test.receive_result sim in
  Systolic_array.Acc_matrix.pp result (fun value ->
      Bits.to_int value |> Int.to_string);
  [%expect {|
    ┌─-----─┐
    │ 2 │ 4 │
    │ 6 │ 8 │
    └─-----─┘
    |}]

let%expect_test "tpu_testbench" =
  let open Make (struct
    let weight_bits = 8
    let data_bits = 8
    let acc_bits = 32
    let size = 2
    let weight_stream_bits = 32
    let data_stream_bits = 32
    let acc_stream_bits = 32
  end) in
  let sim = Test.Sim.create create in
  let waves, sim = Waveform.create sim in
  let i = Cyclesim.inputs sim in
  let cycle () = Cyclesim.cycle sim in
  cycle ();
  Test.send_weight sim (Test.Matrix.of_list [ [ 1; 2 ]; [ 3; 4 ] ]);
  Test.send_data sim (Test.Matrix.of_list [ [ 1; 2 ]; [ 3; 4 ] ]);
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
  Waveform.print waves ~wave_width:4 ~display_width:290 ~display_height:60
    ~signals_width:30;
  [%expect
    {|
    ┌Signals─────────────────────┐┌Waves─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
    │clock                       ││┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐  │
    │                            ││     └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └──│
    │reset                       ││                                                                                                                                                                                                                                                                  │
    │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │acc_dest_tready             ││                                                                                                                                            ┌───────────────────────────────────────────────────────────                                                          │
    │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘                                                                                                                     │
    │clear_accs                  ││                                                                                                                                                                                                                                                                  │
    │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││──────────────────────────────┬─────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │data_source_tdata           ││ 00000000                     │04030201 │00000000                                                                                                                                                                                                                 │
    │                            ││──────────────────────────────┴─────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │data_source_tvalid          ││                              ┌─────────┐                                                                                                                                                                                                                         │
    │                            ││──────────────────────────────┘         └───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │start                       ││                                                            ┌─────────┐                                                                                                                                                                                           │
    │                            ││────────────────────────────────────────────────────────────┘         └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││──────────┬─────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │weight_source_tdata         ││ 00000000 │04030201 │00000000                                                                                                                                                                                                                                     │
    │                            ││──────────┴─────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │weight_source_tvalid        ││          ┌─────────┐                                                                                                                                                                                                                                             │
    │                            ││──────────┘         └───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬─────────────────────────────┬─────────┬─────────┬─────────┬───────────────────                                                          │
    │acc_source_tdata            ││ 00000000                                                                                                               │00000016                     │0000000F │0000000A │00000007 │00000000                                                                     │
    │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴─────────────────────────────┴─────────┴─────────┴─────────┴───────────────────                                                          │
    │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │acc_source_tkeep            ││ F                                                                                                                                                                                                                                                                │
    │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │acc_source_tlast            ││                                                                                                                                                                          ┌─────────┐                                                                             │
    │                            ││──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘         └───────────────────                                                          │
    │acc_source_tvalid           ││                                                                                                                        ┌───────────────────────────────────────────────────────────┐                                                                             │
    │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘                                                           └───────────────────                                                          │
    │data_dest_tready            ││──────────────────────────────────────────────────────────────────────┐                                                                               ┌─────────────────────────────────────────────────                                                          │
    │                            ││                                                                      └───────────────────────────────────────────────────────────────────────────────┘                                                                                                           │
    │                            ││────────────────────────────────────────────────────────────────────────────────┬─────────┬─────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │debug_acc_out_elements00    ││ 00000000                                                                       │00000001 │00000007                                                                                                                                                               │
    │                            ││────────────────────────────────────────────────────────────────────────────────┴─────────┴─────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││──────────────────────────────────────────────────────────────────────────────────────────┬─────────┬───────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │debug_acc_out_elements01    ││ 00000000                                                                                 │00000003 │0000000F                                                                                                                                                     │
    │                            ││──────────────────────────────────────────────────────────────────────────────────────────┴─────────┴───────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││──────────────────────────────────────────────────────────────────────────────────────────┬─────────┬───────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │debug_acc_out_elements10    ││ 00000000                                                                                 │00000002 │0000000A                                                                                                                                                     │
    │                            ││──────────────────────────────────────────────────────────────────────────────────────────┴─────────┴───────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────┬─────────┬─────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │debug_acc_out_elements11    ││ 00000000                                                                                           │00000006 │00000016                                                                                                                                           │
    │                            ││────────────────────────────────────────────────────────────────────────────────────────────────────┴─────────┴─────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │debug_data_in_elements00    ││ 00                                     │01                                                                                                                                                                                                                       │
    │                            ││────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │debug_data_in_elements01    ││ 00                                     │03                                                                                                                                                                                                                       │
    │                            ││────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │debug_data_in_elements10    ││ 00                                     │02                                                                                                                                                                                                                       │
    │                            ││────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │debug_data_in_elements11    ││ 00                                     │04                                                                                                                                                                                                                       │
    │                            ││────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │                            ││────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────                                                          │
    │debug_weight_in_elements00  ││ 00                 │01                                                                                                                                                                                                                                           │
    └────────────────────────────┘└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
    |}]
