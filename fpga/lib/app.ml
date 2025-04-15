open! Base
open Hardcaml

module I = struct
  type 'a t = { clock : 'a; reset : 'a; axi : 'a Axi.Master_to_slave.t }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = { axi : 'a Axi.Slave_to_master.t } [@@deriving sexp_of, hardcaml]
end

let hierarchical ?(name = "app") create_fn scope input =
  let module Hierarchy = Hierarchy.In_scope (I) (O) in
  let output = Hierarchy.hierarchical ~name ~scope create_fn input in
  output
