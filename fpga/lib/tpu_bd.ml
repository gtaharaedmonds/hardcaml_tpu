open! Base
open! Hardcaml

module I = struct
  type 'a t = {
    sys_clk : 'a;
    rst_n : 'a;
    uart_rx : 'a;
    gpio_i : 'a; [@bits 8]
    eth_rmii : 'a Rmii.I.t; [@rtlprefix "eth_rmii_"]
    eth_mdio : 'a Mdio.I.t; [@rtlprefix "eth_mdio_"]
    axi : 'a Axi.Slave_to_master.t; [@rtlprefix "s_axi_"]
  }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = {
    uart_tx : 'a;
    gpio_o : 'a; [@bits 8]
    eth_rmii : 'a Rmii.O.t; [@rtlprefix "eth_rmii_"]
    eth_rst_n : 'a;
    eth_refclk : 'a;
    eth_mdio : 'a Mdio.O.t; [@rtlprefix "eth_mdio_"]
    s_axi_aclk : 'a;
    s_axi_aresetn : 'a;
    axi : 'a Axi.Master_to_slave.t; [@rtlprefix "s_axi_"]
  }
  [@@deriving sexp_of, hardcaml]
end

let create (input : _ I.t) =
  let module Inst = Instantiation.With_interface (I) (O) in
  Inst.create ~name:"tpu_bd" input
