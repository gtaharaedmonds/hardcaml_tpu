open! Base
open! Hardcaml

module I = struct
  type 'a t = {
    resetn : 'a;
    clk : 'a;
    gpio_i : 'a; [@bits 8]
    uart0_rxd_i : 'a;
    axi_s2m : 'a Axi.Slave_to_master.t; [@rtlprefix "m_axi_"]
  }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = {
    gpio_o : 'a; [@bits 8]
    uart0_txd_o : 'a;
    axi_m2s : 'a Axi.Master_to_slave.t; [@rtlprefix "m_axi_"]
  }
  [@@deriving sexp_of, hardcaml]
end

let create (input : _ I.t) =
  let module Inst = Instantiation.With_interface (I) (O) in
  Inst.create ~name:"tpu_nexys_neorv32_vivado_ip_0_0" input
