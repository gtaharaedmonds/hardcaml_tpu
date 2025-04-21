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
    axi_mm2s_0 : 'a Config.Tpu.Stream.Weight_in.Dest.t;
        [@rtlprefix "axi_mm2s_0_"]
    axi_mm2s_1 : 'a Config.Tpu.Stream.Data_in.Dest.t; [@rtlprefix "axi_mm2s_1_"]
    axi_s2mm : 'a Config.Tpu.Stream.Acc_out.Source.t; [@rtlprefix "axi_s2mm_"]
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
    axi_clk : 'a;
    axi_rst_n : 'a;
    axi_mm2s_0 : 'a Config.Tpu.Stream.Weight_in.Source.t;
        [@rtlprefix "axi_mm2s_0_"]
    axi_mm2s_1 : 'a Config.Tpu.Stream.Data_in.Source.t;
        [@rtlprefix "axi_mm2s_1_"]
    axi_s2mm : 'a Config.Tpu.Stream.Acc_out.Dest.t; [@rtlprefix "axi_s2mm_"]
  }
  [@@deriving sexp_of, hardcaml]
end

let create (input : _ I.t) =
  let module Inst = Instantiation.With_interface (I) (O) in
  Inst.create ~name:"tpu_bd" input
