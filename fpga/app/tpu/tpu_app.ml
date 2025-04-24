open! Base
open! Hardcaml
open! Tpu_nexys
open Signal

let clock_divider reg_spec divide_factor =
  let half_divide_factor = divide_factor / 2 in
  let divider_count =
    reg_fb reg_spec ~width:(Int.ceil_log2 half_divide_factor) ~f:(fun count ->
        mux2
          (count ==:. half_divide_factor - 1)
          (zero (width count))
          (count +:. 1))
  in
  (* flip output every half divide factor cycles *)
  reg_fb reg_spec ~width:1 ~f:(fun output ->
      mux2 (divider_count ==:. half_divide_factor - 1) ~:output output)

let create _scope (i : _ App.I.t) =
  let reg_spec = Reg_spec.create ~clock:i.clock ~reset:i.reset () in
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
  let input_freq = 100_000_000 in
  let pwm_freq = 1000 in
  let divider_7segs = clock_divider reg_spec (input_freq / pwm_freq) in
  let hex_7segs =
    {
      clock = divider_7segs;
      reset = i.reset;
      Hex_7segs.I.enables = List.init 8 ~f:(fun i -> if i = 3 then gnd else vdd);
      values = List.init 8 ~f:(fun i -> of_int ~width:4 i);
    }
  in
  {
    App.O.weight_dest = tpu.weight_dest;
    data_dest = tpu.data_dest;
    acc_source = tpu.acc_source;
    gpio_i;
    leds = i.gpio_o;
    hex_7segs;
  }

let () = Stdio.print_string (Tpu_nexys.Rtl_generator.generate "tpu_top" create)
