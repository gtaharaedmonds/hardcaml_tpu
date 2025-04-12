open! Base
open Hardcaml

module I = struct
  type 'a t = { clock : 'a; reset : 'a } [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = { unused : 'a } [@@deriving sexp_of, hardcaml]
end

let hierarchical ?(name = "app") create_fn scope input =
  let module Hierarchy = Hierarchy.In_scope (I) (O) in
  let output = Hierarchy.hierarchical ~name ~scope create_fn input in
  output
