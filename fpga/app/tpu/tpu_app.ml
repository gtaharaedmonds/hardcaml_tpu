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
  let edge_detect s =
    let prev_s = reg reg_spec s in
    s &&: ~:prev_s
  in
  let clear_accs = edge_detect (bit i.gpio_o 0) in
  let start = edge_detect (bit i.gpio_o 1) in
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
      Hex_7segs.I.enables = of_bit_string "11111111" |> bits_lsb;
      values =
        List.init 4 ~f:(fun idx ->
            let debug_select = select i.switches 1 0 in
            let row = idx / 2 in
            let col = idx % 2 in
            let weight =
              Config.Tpu.Systolic_array.Weight_matrix.get tpu.debug_weight_in
                ~row ~col
            in
            let data =
              Config.Tpu.Systolic_array.Data_matrix.get tpu.debug_data_in ~row
                ~col
            in
            let acc =
              Config.Tpu.Systolic_array.Acc_matrix.get tpu.debug_acc_out ~row
                ~col
            in
            let byte =
              mux debug_select [ weight; data; sel_bottom acc 8; zero 8 ]
            in
            [ sel_bottom byte 4; sel_top byte 4 ])
        |> List.concat;
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
