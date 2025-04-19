open! Base
open! Hardcaml

module type Config = sig
  val bits : int
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
  module Config : Config
  module Source : Source
  module Dest : Dest
end

module type Adapter = sig
  module Master : S
  module Slave : S

  (* module I : sig
    type 'a t = {
      master_source : 'a Master.Source.t;
      slave_dest : 'a Slave.Dest.t;
    }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t = {
      master_dest : 'a Master.Dest.t;
      slave_source : 'a Slave.Source.t;
    }
    [@@deriving hardcaml]
  end

  val create : Signal.t I.t -> Signal.t O.t *)
end

module type Axi_stream = sig
  module type S = S

  module Make (Config : Config) : S

  module Adapter : sig
    module Make (Master : S) (Slave : S) :
      Adapter with module Master := Master with module Slave := Slave
  end
end
