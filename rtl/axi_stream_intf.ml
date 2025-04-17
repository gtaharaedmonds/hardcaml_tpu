open! Base
open! Hardcaml

module type Config = sig
  val bus_bits : int
  val mailbox_bits : int
end

module type Source = sig
  type 'a t = {
    tvalid : 'a; (* high when data is available *)
    tdata : 'a; (* data bus, valid when tvalid is high *)
  }
  [@@deriving hardcaml]
end

module type Dest = sig
  type 'a t = {
    tready : 'a; (* high when the destination can receive more data *)
  }
  [@@deriving hardcaml]
end

(* some AXI-Stream signals are omitted since I don't plan on using them: tkeep,
tlast, tid, tuser *)

module type S = sig
  module Source : Source
  module Dest : Dest

  val create : Signal.t Source.t -> Signal.t Dest.t
end

module type Axi_stream = sig
  module type S = S

  module Make (Config : Config) : S
end
