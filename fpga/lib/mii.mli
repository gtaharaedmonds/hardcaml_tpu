open! Base
open! Hardcaml

module I : sig
  type 'a t = {
    col : 'a;
    crs : 'a;
    rx_clk : 'a;
    rx_dv : 'a;
    rx_er : 'a;
    rxd : 'a; [@bits 4]
    tx_clk : 'a;
  }
  [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t = { tx_en : 'a; tx_er : 'a; txd : 'a [@bits 4] }
  [@@deriving sexp_of, hardcaml]
end
