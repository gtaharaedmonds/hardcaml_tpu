open! Base
open! Hardcaml
include Axi_stream_intf

module Make (Config : Config) = struct
  module Source = struct
    type 'a t = { tvalid : 'a; tdata : 'a [@bits Config.bus_bits] }
    [@@deriving hardcaml]
  end

  module Dest = struct
    type 'a t = { tready : 'a } [@@deriving hardcaml]
  end

  let create _src = failwith "todo"
end
