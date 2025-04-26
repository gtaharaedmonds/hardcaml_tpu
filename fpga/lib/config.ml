module Tpu = Tpu.Make (struct
  let weight_bits = 8
  let data_bits = 8
  let acc_bits = 32
  let weight_stream_bits = 32
  let data_stream_bits = 32
  let acc_stream_bits = 32
  let size = 8
end)
