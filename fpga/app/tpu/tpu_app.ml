open! Base
open! Hardcaml
open! Tpu_nexys

let create _scope (i : _ App.I.t) =
  let open Signal in
  let clear_accs = bit i.gpio_o 0 in
  let start = bit i.gpio_o 1 in
  let tpu =
    Config.Tpu.create
      {
        Config.Tpu.I.clock = i.clock;
        reset = i.reset;
        clear_accs;
        start;
        weight_source = i.weight_source;
        data_source = i.data_source;
        acc_dest = i.acc_dest;
      }
  in
  let gpio_i = concat_lsb [ tpu.ready; tpu.finished; repeat gnd 6 ] in
  {
    App.O.weight_dest = tpu.weight_dest;
    data_dest = tpu.data_dest;
    acc_source = tpu.acc_source;
    gpio_i;
    leds = gpio_i;
  }

let () = Stdio.print_string (Tpu_nexys.Rtl_generator.generate "tpu_top" create)
