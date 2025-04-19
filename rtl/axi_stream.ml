open! Base
open! Hardcaml
open Hardcaml_waveterm
include Axi_stream_intf

module Make (Config : Config) = struct
  module Config = Config
  open Config

  module Source = struct
    type 'a t = { tvalid : 'a; tdata : 'a [@bits bits] } [@@deriving hardcaml]
  end

  module Dest = struct
    type 'a t = { tready : 'a } [@@deriving hardcaml]
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
        let sm = Always.State_machine.create (module States) reg_spec in
        Always.(
          compile
            [
              slave_source.tdata
              <-- (List.map transfer_regs ~f:(fun reg -> reg.value)
                  |> concat_lsb);
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
      let create (_i : _ I.t) = failwith "todo"
    end

    let create =
      if Master.Config.bits = Slave.Config.bits then Equal_widths.create
      else if Master.Config.bits < Slave.Config.bits then Width_expander.create
      else Width_reducer.create
  end
end

let testbench_width_expander () =
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

  waves

let testbench_equal_widths () =
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

  waves

let%expect_test "testbench_width_expander" =
  let waves = testbench_width_expander () in
  Waveform.print waves ~wave_width:4 ~display_width:110 ~display_height:20;
  [%expect {||}]

let%expect_test "testbench_equal_widths" =
  let waves = testbench_equal_widths () in
  Waveform.print waves ~wave_width:4 ~display_width:110 ~display_height:20;
  [%expect {||}]
