open! Base
open! Hardcaml
open! Tpu_nexys
open! Signal

let create scope (input : _ App.I.t) =
  ignore scope;
  ignore input;
  {
    App.O.weight_dest = Config.Tpu.Stream.Weight_in.Dest.Of_signal.of_int 0;
    data_dest = Config.Tpu.Stream.Data_in.Dest.Of_signal.of_int 0;
    acc_source = Config.Tpu.Stream.Acc_out.Source.Of_signal.of_int 0;
    gpio_i = zero 8;
    leds = zero 8;
  }

let () =
  Stdio.print_string (Tpu_nexys.Rtl_generator.generate "demo_system_top" create)
