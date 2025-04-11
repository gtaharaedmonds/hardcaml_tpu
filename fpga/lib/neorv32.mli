open! Base
open! Hardcaml

module I : sig
  type 'a t = {
    resetn : 'a;
    clk : 'a;
    gpio_i : 'a; [@bits 8]
    uart0_rxd_i : 'a;
    axi_s2m : 'a Axi.Slave_to_master.t; [@rtlprefix "m_axi_"]
  }
  [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t = {
    gpio_o : 'a; [@bits 8]
    uart0_txd_o : 'a;
    axi_m2s : 'a Axi.Master_to_slave.t; [@rtlprefix "m_axi_"]
  }
  [@@deriving sexp_of, hardcaml]
end

val create : Signal.t I.t -> Signal.t O.t
