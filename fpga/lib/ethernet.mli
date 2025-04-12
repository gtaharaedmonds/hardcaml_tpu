open! Base
open! Hardcaml

module I : sig
  type 'a t = {
    s_axi_aresetn : 'a;
    s_axi_aclk : 'a;
    axi_m2s : 'a Axi.Master_to_slave.t;
    mii_in : 'a Mii.I.t;
    mdio_i : 'a Mdio.I.t;
  }
  [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t = {
    axi_s2m : 'a Axi.Slave_to_master.t;
    ip2intc_irpt : 'a;
    phy_rst_n : 'a;
    mii_out : 'a Mii.O.t;
    mdio_o : 'a Mdio.O.t;
  }
  [@@deriving sexp_of, hardcaml]
end

val create : Signal.t I.t -> Signal.t O.t
