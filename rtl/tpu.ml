open Base
open! Hardcaml
open Hardcaml_waveterm
include Tpu_intf

module Make (Config : Config) = struct
  include Config
  module Axi_stream = Axi_stream.Make (Config.Axi_stream_config)
  module Systolic_array = Systolic_array.Make (Config.Systolic_array_config)
  open Systolic_array

  module I = struct
    type 'a t = {
      reset : 'a;
      clock : 'a;
      clear_accs : 'a;
      start : 'a;
      data_source : 'a Axi_stream.Source.t; [@rtlprefix "data_source_"]
      acc_dest : 'a Axi_stream.Dest.t; [@rtlprefix "acc_dest_"]
      weight_source : 'a Axi_stream.Source.t; [@rtlprefix "weight_source_"]
    }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t = {
      ready : 'a;
      finished : 'a;
      weight_dest : 'a Axi_stream.Dest.t; [@rtlprefix "weight_dest_"]
      data_dest : 'a Axi_stream.Dest.t; [@rtlprefix "data_dest_"]
      acc_source : 'a Axi_stream.Source.t; [@rtlprefix "acc_source_"]
      acc_out : 'a Acc_matrix.t;
      data_in : 'a Data_matrix.t; [@rtlprefix "debug_data_"]
      weight_in : 'a Weight_matrix.t; [@rtlprefix "debug_weight_"]
    }
    [@@deriving hardcaml]
  end

  let create_stream_input_mailbox (module Interface : Interface.S) reg_spec
      (source : _ Axi_stream.Source.t) =
    let open Signal in
    let mailbox_width = Interface.sum_of_port_widths in
    if not (mailbox_width % Axi_stream.Config.bits = 0) then
      raise_s [%message "mailbox size mismatch!"];
    let num_transfers = mailbox_width / Axi_stream.Config.bits in
    (* create a wrapping counter for the mailbox stages *)
    let transfer_count =
      reg_fb reg_spec ~width:(address_bits_for num_transfers) ~f:(fun count ->
          priority_select_with_default
            [
              (* if destination isn't ready, don't increment transfer count *)
              { valid = ~:(source.tvalid); value = count };
              (* if all transfers are complete, reset to 0 *)
              {
                valid = count ==:. num_transfers - 1;
                value = zero (width count);
              };
            ]
            (* default case: move to next transfer *)
            ~default:(count +:. 1))
    in
    let mailbox =
      List.init num_transfers ~f:(fun stage ->
          reg reg_spec
            ~enable:(source.tvalid &&: transfer_count ==:. stage)
            source.tdata)
      |> concat_lsb
    in
    (mailbox, { Axi_stream.Dest.tready = vdd })

  let create_stream_output_mailbox reg_spec acc_out (dest : _ Axi_stream.Dest.t)
      =
    let open Signal in
    let total_width = Acc_matrix.sum_of_port_widths in
    if not (total_width % Axi_stream.Config.bits = 0) then
      raise_s [%message "width mismatch!"];
    let transfer_mailboxes =
      Acc_matrix.Of_signal.pack acc_out
      |> bits_lsb
      |> List.chunks_of ~length:Axi_stream.Config.bits
      |> List.map ~f:concat_lsb
    in
    let num_transfers = List.length transfer_mailboxes in
    let transfer_count =
      reg_fb reg_spec ~width:(address_bits_for num_transfers) ~f:(fun count ->
          priority_select_with_default
            [
              (* if destination isn't ready, don't increment transfer count *)
              { valid = ~:(dest.tready); value = count };
              (* if all transfers are complete, reset to 0 *)
              {
                valid = count ==:. num_transfers - 1;
                value = zero (width count);
              };
            ]
            (* default case: move to next transfer *)
            ~default:(count +:. 1))
    in
    let source_data = mux transfer_count transfer_mailboxes in
    { Axi_stream.Source.tdata = source_data; tvalid = ones 1 }

  let create (i : _ I.t) =
    (* let open Signal in *)
    let reg_spec = Reg_spec.create ~clock:i.clock ~reset:i.reset () in
    let data_mailbox, data_dest =
      create_stream_input_mailbox (module Data_matrix) reg_spec i.data_source
    in
    let weight_mailbox, weight_dest =
      create_stream_input_mailbox
        (module Weight_matrix)
        reg_spec i.weight_source
    in
    let weight_in = Weight_matrix.Of_signal.unpack weight_mailbox in
    let data_in = Data_matrix.Of_signal.unpack data_mailbox in
    let systolic_array =
      Systolic_array.create
        {
          Systolic_array.I.clock = i.clock;
          reset = i.reset;
          clear_accs = i.clear_accs;
          start = i.start;
          weight_in;
          data_in;
        }
    in
    (* let acc_buf =
      Acc_matrix.create ~f:(fun row col ->
          reg reg_spec (Acc_matrix.get ~row ~col systolic_array.acc_out))
    in *)
    let acc_source =
      create_stream_output_mailbox reg_spec systolic_array.acc_out i.acc_dest
    in
    {
      O.data_dest;
      weight_dest;
      acc_source;
      acc_out = systolic_array.acc_out;
      ready = systolic_array.ready;
      finished = systolic_array.finished;
      data_in;
      weight_in;
    }
end

module Test = struct
  module Tpu = Make (struct
    module Systolic_array_config = struct
      let data_bits = 8
      let weight_bits = 8
      let acc_bits = 32
      let size = 2
    end

    module Axi_stream_config = struct
      let bits = 8
    end
  end)

  module Sim = Cyclesim.With_interface (Tpu.I) (Tpu.O)

  let send_data (sim : Sim.t) ~f =
    let open Tpu.Systolic_array in
    let open Config in
    let inputs = Cyclesim.inputs sim in
    let outputs = Cyclesim.outputs sim in
    let data =
      Data_matrix.create ~f:(fun row col ->
          f row col |> Bits.of_int ~width:data_bits)
    in
    Data_matrix.Of_bits.pack data
    |> Bits.bits_lsb
    |> List.chunks_of ~length:data_bits
    |> List.map ~f:Bits.concat_lsb
    |> List.iter ~f:(fun transfer ->
           while Bits.equal !(outputs.data_dest.tready) Bits.gnd do
             Cyclesim.cycle sim
           done;
           inputs.data_source.tdata := transfer;
           inputs.data_source.tvalid := Bits.vdd;
           Cyclesim.cycle sim;
           inputs.data_source.tdata := Bits.zero Tpu.Axi_stream.Config.bits;
           inputs.data_source.tvalid := Bits.gnd;
           Cyclesim.cycle sim)

  let send_weight (sim : Sim.t) ~f =
    let open Tpu.Systolic_array in
    let open Config in
    let inputs = Cyclesim.inputs sim in
    let outputs = Cyclesim.outputs sim in
    let data =
      Weight_matrix.create ~f:(fun row col ->
          f row col |> Bits.of_int ~width:data_bits)
    in
    Weight_matrix.Of_bits.pack data
    |> Bits.bits_lsb
    |> List.chunks_of ~length:data_bits
    |> List.map ~f:Bits.concat_lsb
    |> List.iter ~f:(fun transfer ->
           while Bits.equal !(outputs.data_dest.tready) Bits.gnd do
             Cyclesim.cycle sim
           done;
           inputs.weight_source.tdata := transfer;
           inputs.weight_source.tvalid := Bits.vdd;
           Cyclesim.cycle sim;
           inputs.weight_source.tdata := Bits.zero Tpu.Axi_stream.Config.bits;
           inputs.weight_source.tvalid := Bits.gnd;
           Cyclesim.cycle sim)

  let testbench () =
    let open! Tpu.Systolic_array.Config in
    let sim = Sim.create ~config:Cyclesim.Config.trace_all Tpu.create in
    let waves, sim = Waveform.create sim in
    let inputs = Cyclesim.inputs sim in
    let _outputs = Cyclesim.outputs sim in
    let cycle () = Cyclesim.cycle sim in
    cycle ();
    send_data sim ~f:(fun row col -> (row * size) + col + 1);
    send_weight sim ~f:(fun row col -> (row * size) + col + 1);
    cycle ();
    inputs.clear_accs := Bits.vdd;
    cycle ();
    inputs.clear_accs := Bits.gnd;
    cycle ();
    inputs.start := Bits.vdd;
    cycle ();
    inputs.start := Bits.gnd;
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    cycle ();
    waves
end

let%expect_test "tpu_testbench" =
  let waves = Test.testbench () in
  Waveform.print waves ~wave_width:1 ~display_width:150 ~display_height:80
    ~signals_width:30;
  [%expect {||}]
