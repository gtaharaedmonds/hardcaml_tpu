open! Base
open! Hardcaml

module I = struct
  type 'a t = { crs_dv : 'a; rx_er : 'a; rxd : 'a [@bits 2] }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = { tx_en : 'a; txd : 'a [@bits 2] } [@@deriving sexp_of, hardcaml]
end
