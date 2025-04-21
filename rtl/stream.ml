open! Base
open! Hardcaml
open Hardcaml_waveterm
include Stream_intf

module Make (Config : Config) = struct
  module Config = Config
  open Config

  module Source = struct
    type 'a t = {
      tvalid : 'a;
      tdata : 'a; [@bits bits]
      tkeep : 'a; [@bits bits / 8]
      tlast : 'a;
    }
    [@@deriving hardcaml]
  end

  module Dest = struct
    type 'a t = { tready : 'a } [@@deriving hardcaml]
  end

  module Test = struct
    let send sim (source : Bits.t ref Source.t) (dest : Bits.t ref Dest.t) data
        =
      if not (Bits.width data % Config.bits = 0) then
        raise_s
          [%message
            "the width of the signal you're trying to send needs to be \
             divisible by the AXI stream bus width"
              (Bits.width data : int)
              (Config.bits : int)];
      data |> Bits.bits_lsb
      |> List.chunks_of ~length:bits
      |> List.map ~f:Bits.concat_lsb
      |> List.iter ~f:(fun transfer ->
             while Bits.equal !(dest.tready) Bits.gnd do
               Cyclesim.cycle sim
             done;
             source.tdata := transfer;
             source.tvalid := Bits.vdd;
             Cyclesim.cycle sim);
      source.tvalid := Bits.gnd;
      Cyclesim.cycle sim

    let receive sim (source : Bits.t ref Source.t) (dest : Bits.t ref Dest.t)
        ~len =
      let num_transfers = len / Config.bits in
      dest.tready := Bits.vdd;
      let data =
        List.init num_transfers ~f:(fun _ ->
            while Bits.equal !(source.tvalid) Bits.gnd do
              Cyclesim.cycle sim
            done;
            let data = !(source.tdata) in
            Cyclesim.cycle sim;
            data)
        |> Bits.concat_lsb
      in
      dest.tready := Bits.gnd;
      Cyclesim.cycle sim;
      data
  end
end

module Adapter = struct
  module Make (Master : S) (Slave : S) = struct
    module Master = Master
    module Slave = Slave

    module I = struct
      type 'a t = {
        reset : 'a;
        clock : 'a;
        master_source : 'a Master.Source.t; [@rtlprefix "master_source_"]
        slave_dest : 'a Slave.Dest.t; [@rtlprefix "slave_dest_"]
      }
      [@@deriving hardcaml]
    end

    module O = struct
      type 'a t = {
        master_dest : 'a Master.Dest.t; [@rtlprefix "master_dest_"]
        slave_source : 'a Slave.Source.t; [@rtlprefix "slave_source_"]
      }
      [@@deriving hardcaml]
    end

    module Equal_widths = struct
      let create (i : _ I.t) =
        {
          O.master_dest = { Master.Dest.tready = i.slave_dest.tready };
          slave_source =
            {
              Slave.Source.tdata = i.master_source.tdata;
              tvalid = i.master_source.tvalid;
              tkeep = i.master_source.tkeep;
              tlast = i.master_source.tlast;
            };
        }
    end

    module Width_expander = struct
      module States = struct
        type t = Input_incomplete | Output_available
        [@@deriving sexp_of, compare, enumerate]
      end

      let create (i : _ I.t) =
        let open Signal in
        let reg_spec = Reg_spec.create ~reset:i.reset ~clock:i.clock () in
        let master_dest = Master.Dest.Of_always.wire zero in
        let slave_source = Slave.Source.Of_always.wire zero in
        let num_transfers = Slave.Config.bits / Master.Config.bits in
        let transfer_counter =
          Always.Variable.reg
            ~width:(address_bits_for (num_transfers + 1))
            reg_spec
        in
        let transfer_regs =
          List.init num_transfers ~f:(fun _ ->
              Always.Variable.reg ~width:Master.Config.bits reg_spec)
        in
        let output_buf =
          List.map transfer_regs ~f:(fun reg -> reg.value) |> concat_lsb
        in
        let sm = Always.State_machine.create (module States) reg_spec in
        Always.(
          compile
            [
              slave_source.tdata <-- output_buf;
              slave_source.tkeep <--. 0xF;
              slave_source.tlast <--. 0;
              sm.switch
                [
                  ( States.Input_incomplete,
                    [
                      master_dest.tready <--. 1;
                      when_ i.master_source.tvalid
                        (List.concat
                           [
                             List.mapi transfer_regs ~f:(fun reg_i reg ->
                                 when_
                                   (transfer_counter.value ==:. reg_i)
                                   [ reg <-- i.master_source.tdata ]);
                             [
                               if_
                                 (transfer_counter.value ==:. num_transfers - 1)
                                 [
                                   transfer_counter <--. 0;
                                   sm.set_next States.Output_available;
                                 ]
                                 [
                                   transfer_counter
                                   <-- transfer_counter.value +:. 1;
                                 ];
                             ];
                           ]);
                    ] );
                  ( States.Output_available,
                    [
                      slave_source.tvalid <--. 1;
                      when_ i.slave_dest.tready
                        [ sm.set_next States.Input_incomplete ];
                    ] );
                ];
            ]);
        {
          O.master_dest = Master.Dest.Of_always.value master_dest;
          slave_source = Slave.Source.Of_always.value slave_source;
        }
    end

    module Width_reducer = struct
      module States = struct
        type t = Waiting_for_input | Transferring_output
        [@@deriving sexp_of, compare, enumerate]
      end

      let create (i : _ I.t) =
        let open Signal in
        let reg_spec = Reg_spec.create ~clock:i.clock ~reset:i.reset () in
        let master_dest = Master.Dest.Of_always.wire zero in
        let slave_source = Slave.Source.Of_always.wire zero in
        let num_transfers = Master.Config.bits / Slave.Config.bits in
        let transfer_counter =
          Always.Variable.reg
            ~width:(address_bits_for (num_transfers + 1))
            reg_spec
        in
        let input_buf =
          Always.Variable.reg ~width:Master.Config.bits reg_spec
        in
        let transfer_regs =
          bits_lsb input_buf.value
          |> List.chunks_of ~length:Slave.Config.bits
          |> List.map ~f:concat_lsb
        in
        let sm = Always.State_machine.create (module States) reg_spec in
        Always.(
          compile
            [
              slave_source.tdata
              <-- mux
                    (of_int ~width:(width transfer_counter.value) num_transfers
                    -: transfer_counter.value -:. 1)
                    transfer_regs;
              slave_source.tkeep <--. 0xF;
              slave_source.tlast <--. 0;
              sm.switch
                [
                  ( States.Waiting_for_input,
                    [
                      master_dest.tready <--. 1;
                      when_ i.master_source.tvalid
                        [
                          input_buf <-- i.master_source.tdata;
                          sm.set_next States.Transferring_output;
                        ];
                    ] );
                  ( States.Transferring_output,
                    [
                      slave_source.tvalid <--. 1;
                      when_ i.slave_dest.tready
                        [
                          if_
                            (transfer_counter.value ==:. num_transfers - 1)
                            [
                              transfer_counter <--. 0;
                              input_buf <--. 0;
                              sm.set_next States.Waiting_for_input;
                            ]
                            [
                              transfer_counter <-- transfer_counter.value +:. 1;
                            ];
                        ];
                    ] );
                ];
            ]);
        {
          O.master_dest = Master.Dest.Of_always.value master_dest;
          slave_source = Slave.Source.Of_always.value slave_source;
        }
    end

    let create =
      if Master.Config.bits = Slave.Config.bits then Equal_widths.create
      else if Master.Config.bits < Slave.Config.bits then Width_expander.create
      else Width_reducer.create
  end
end

let%expect_test "equal_widths_testbench" =
  let module Master = Make (struct
    let bits = 8
  end) in
  let module Slave = Make (struct
    let bits = 8
  end) in
  let open Adapter.Make (Master) (Slave) in
  let module Sim = Cyclesim.With_interface (I) (O) in
  let sim = Sim.create create in
  let waves, sim = Waveform.create sim in
  let cycle () = Cyclesim.cycle sim in
  let i = Cyclesim.inputs sim in
  cycle ();
  i.master_source.tvalid := Bits.vdd;
  i.master_source.tdata := Bits.of_int ~width:8 0x01;
  cycle ();
  i.master_source.tdata := Bits.of_int ~width:8 0x02;
  cycle ();
  i.master_source.tdata := Bits.of_int ~width:8 0x03;
  cycle ();
  i.master_source.tdata := Bits.of_int ~width:8 0x04;
  cycle ();
  i.master_source.tvalid := Bits.gnd;
  cycle ();
  i.slave_dest.tready := Bits.vdd;
  cycle ();
  i.slave_dest.tready := Bits.gnd;
  cycle ();
  Waveform.print waves ~wave_width:4 ~display_width:110 ~display_height:25;
  [%expect
    {|
    ┌Signals───────────┐┌Waves───────────────────────────────────────────────────────────────────────────────────┐
    │                  ││──────────┬─────────┬─────────┬─────────┬───────────────────────────────────────        │
    │master_source_tdat││ 00       │01       │02       │03       │04                                             │
    │                  ││──────────┴─────────┴─────────┴─────────┴───────────────────────────────────────        │
    │master_source_tval││          ┌───────────────────────────────────────┐                                     │
    │                  ││──────────┘                                       └─────────────────────────────        │
    │slave_dest_tready ││                                                            ┌─────────┐                 │
    │                  ││────────────────────────────────────────────────────────────┘         └─────────        │
    │master_dest_tready││                                                            ┌─────────┐                 │
    │                  ││────────────────────────────────────────────────────────────┘         └─────────        │
    │                  ││──────────┬─────────┬─────────┬─────────┬───────────────────────────────────────        │
    │slave_source_tdata││ 00       │01       │02       │03       │04                                             │
    │                  ││──────────┴─────────┴─────────┴─────────┴───────────────────────────────────────        │
    │slave_source_tvali││          ┌───────────────────────────────────────┐                                     │
    │                  ││──────────┘                                       └─────────────────────────────        │
    │                  ││                                                                                        │
    │                  ││                                                                                        │
    │                  ││                                                                                        │
    │                  ││                                                                                        │
    └──────────────────┘└────────────────────────────────────────────────────────────────────────────────────────┘
  |}]

let%expect_test "width_expander_testbench" =
  let module Master = Make (struct
    let bits = 8
  end) in
  let module Slave = Make (struct
    let bits = 32
  end) in
  let open Adapter.Make (Master) (Slave) in
  let module Sim = Cyclesim.With_interface (I) (O) in
  let sim = Sim.create create in
  let waves, sim = Waveform.create sim in
  let cycle () = Cyclesim.cycle sim in
  let i = Cyclesim.inputs sim in
  cycle ();
  i.master_source.tvalid := Bits.vdd;
  i.master_source.tdata := Bits.of_int ~width:8 0x01;
  cycle ();
  i.master_source.tdata := Bits.of_int ~width:8 0x02;
  cycle ();
  i.master_source.tdata := Bits.of_int ~width:8 0x03;
  cycle ();
  i.master_source.tdata := Bits.of_int ~width:8 0x04;
  cycle ();
  i.master_source.tvalid := Bits.gnd;
  cycle ();
  i.slave_dest.tready := Bits.vdd;
  cycle ();
  i.slave_dest.tready := Bits.gnd;
  cycle ();
  Waveform.print waves ~wave_width:4 ~display_width:110 ~display_height:25;
  [%expect
    {|
    ┌Signals───────────┐┌Waves───────────────────────────────────────────────────────────────────────────────────┐
    │clock             ││┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐  │
    │                  ││     └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └──│
    │reset             ││                                                                                        │
    │                  ││────────────────────────────────────────────────────────────────────────────────        │
    │                  ││──────────┬─────────┬─────────┬─────────┬───────────────────────────────────────        │
    │master_source_tdat││ 00       │01       │02       │03       │04                                             │
    │                  ││──────────┴─────────┴─────────┴─────────┴───────────────────────────────────────        │
    │master_source_tval││          ┌───────────────────────────────────────┐                                     │
    │                  ││──────────┘                                       └─────────────────────────────        │
    │slave_dest_tready ││                                                            ┌─────────┐                 │
    │                  ││────────────────────────────────────────────────────────────┘         └─────────        │
    │master_dest_tready││──────────────────────────────────────────────────┐                   ┌─────────        │
    │                  ││                                                  └───────────────────┘                 │
    │                  ││────────────────────┬─────────┬─────────┬─────────┬─────────────────────────────        │
    │slave_source_tdata││ 00000000           │00000001 │00000201 │00030201 │04030201                             │
    │                  ││────────────────────┴─────────┴─────────┴─────────┴─────────────────────────────        │
    │slave_source_tvali││                                                  ┌───────────────────┐                 │
    │                  ││──────────────────────────────────────────────────┘                   └─────────        │
    └──────────────────┘└────────────────────────────────────────────────────────────────────────────────────────┘
  |}]

let%expect_test "width_reducer_testbench" =
  let module Master = Make (struct
    let bits = 32
  end) in
  let module Slave = Make (struct
    let bits = 8
  end) in
  let open Adapter.Make (Master) (Slave) in
  let module Sim = Cyclesim.With_interface (I) (O) in
  let sim = Sim.create create in
  let waves, sim = Waveform.create sim in
  let cycle () = Cyclesim.cycle sim in
  let i = Cyclesim.inputs sim in
  cycle ();
  i.master_source.tvalid := Bits.vdd;
  i.master_source.tdata := Bits.of_int ~width:32 0x01020304;
  cycle ();
  i.master_source.tvalid := Bits.gnd;
  cycle ();
  i.slave_dest.tready := Bits.vdd;
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  Waveform.print waves ~wave_width:4 ~display_width:110 ~display_height:25;
  [%expect
    {|
    ┌Signals───────────┐┌Waves───────────────────────────────────────────────────────────────────────────────────┐
    │clock             ││┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐  │
    │                  ││     └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └────┘    └──│
    │reset             ││                                                                                        │
    │                  ││────────────────────────────────────────────────────────────────────────────────────────│
    │                  ││──────────┬─────────────────────────────────────────────────────────────────────────────│
    │master_source_tdat││ 00000000 │01020304                                                                     │
    │                  ││──────────┴─────────────────────────────────────────────────────────────────────────────│
    │master_source_tval││          ┌─────────┐                                                                   │
    │                  ││──────────┘         └───────────────────────────────────────────────────────────────────│
    │slave_dest_tready ││                              ┌─────────────────────────────────────────────────────────│
    │                  ││──────────────────────────────┘                                                         │
    │master_dest_tready││────────────────────┐                                                 ┌─────────────────│
    │                  ││                    └─────────────────────────────────────────────────┘                 │
    │                  ││────────────────────┬───────────────────┬─────────┬─────────┬─────────┬─────────────────│
    │slave_source_tdata││ 00                 │01                 │02       │03       │04       │00               │
    │                  ││────────────────────┴───────────────────┴─────────┴─────────┴─────────┴─────────────────│
    │slave_source_tvali││                    ┌─────────────────────────────────────────────────┐                 │
    │                  ││────────────────────┘                                                 └─────────────────│
    └──────────────────┘└────────────────────────────────────────────────────────────────────────────────────────┘
  |}]
