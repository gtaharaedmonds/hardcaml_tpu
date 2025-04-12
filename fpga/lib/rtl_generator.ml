open! Base
open! Hardcaml

(* I don't think Hardcaml.Signal supports tri-state logic? (Which I need for
MDIO to configure the PHY!) So I've made a System module, which has basically
the entire design and uses Hardcaml.Signal, and a wrapper Top module which
instantiates the tri-state buffer. Top uses Hardcaml.Structural instead which
supports tri-state logic. *)

type create_fn = Scope.t -> Signal.t App.I.t -> Signal.t App.O.t

module System = struct
  module I = struct
    type 'a t = {
      rst_n : 'a;
      sys_clk : 'a;
      switches : 'a; [@bits 8]
      uart_rx : 'a;
      eth_rmii_in : 'a Rmii.I.t; [@rtlprefix "eth_rmii_"]
      eth_intn : 'a;
      eth_mdio_i : 'a Mdio.I.t; [@rtlprefix "eth_"]
    }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      leds : 'a; [@bits 8]
      uart_tx : 'a;
      eth_ref_clk : 'a;
      eth_rst_n : 'a;
      eth_rmii_out : 'a Rmii.O.t; [@rtlprefix "eth_rmii_"]
      eth_mdio_o : 'a Mdio.O.t; [@rtlprefix "eth_"]
    }
    [@@deriving sexp_of, hardcaml]
  end

  let create (create_fn : create_fn) scope (i : _ I.t) =
    let open Signal in
    let {
      Clock_wizard.O.locked = rst_n;
      clk_out1 = axi_clk;
      clk_out2 = phy_ref_clk;
      clk_out3 = phy_ref_clk_delayed;
    } =
      Clock_wizard.create { clk_in1 = i.sys_clk; resetn = i.rst_n }
    in
    let axi_s2m = Axi.Slave_to_master.Of_signal.wires () in
    let cpu =
      Neorv32.create
        {
          resetn = rst_n;
          clk = axi_clk;
          gpio_i = i.switches;
          uart0_rxd_i = i.uart_rx;
          axi_s2m;
        }
    in
    let mii_out = Mii.O.Of_signal.wires () in
    let mii_to_rmii =
      Mii_to_rmii.create
        { rst_n; ref_clk = phy_ref_clk; mii_out; rmii_in = i.eth_rmii_in }
    in
    let eth =
      Ethernet.create
        {
          s_axi_aresetn = rst_n;
          s_axi_aclk = axi_clk;
          axi_m2s = cpu.axi_m2s;
          mii_in = mii_to_rmii.mii_in;
          mdio_i = i.eth_mdio_i;
        }
    in
    Axi.Slave_to_master.Of_signal.assign axi_s2m eth.axi_s2m;
    Mii.O.Of_signal.assign mii_out eth.mii_out;
    let app =
      App.hierarchical create_fn scope { clock = axi_clk; reset = ~:rst_n }
    in
    ignore app;
    {
      O.leds = cpu.gpio_o;
      uart_tx = cpu.uart0_txd_o;
      eth_ref_clk = phy_ref_clk_delayed;
      eth_rst_n = eth.phy_rst_n;
      eth_rmii_out = mii_to_rmii.rmii_out;
      eth_mdio_o = eth.mdio_o;
    }
end

module Top = struct
  module I = struct
    type 'a t = {
      rst_n : 'a;
      sys_clk : 'a;
      switches : 'a; [@bits 8]
      uart_rx : 'a;
      eth_rmii_in : 'a Rmii.I.t; [@rtlprefix "eth_rmii_"]
      eth_intn : 'a;
    }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      leds : 'a; [@bits 8]
      uart_tx : 'a;
      eth_ref_clk : 'a;
      eth_rst_n : 'a;
      eth_rmii_out : 'a Rmii.O.t; [@rtlprefix "eth_rmii_"]
      eth_mdc : 'a;
    }
    [@@deriving sexp_of, hardcaml]
  end

  module T = struct
    type 'a t = { eth_mdio : 'a } [@@deriving sexp_of, hardcaml]
  end

  module Iobuf = struct
    module I = struct
      type 'a t = { i : 'a; [@rtlname "I"] t : 'a [@rtlname "T"] }
      [@@deriving sexp_of, hardcaml]
    end

    module O = struct
      type 'a t = { o : 'a [@rtlname "O"] } [@@deriving sexp_of, hardcaml]
    end

    module T = struct
      type 'a t = { io : 'a [@rtlname "IO"] } [@@deriving sexp_of, hardcaml]
    end
  end

  let create name (i : _ I.t) (o : _ O.t) (t : _ T.t) =
    let open Structural in
    let module C_iobuf = With_interface (Iobuf.I) (Iobuf.O) (Iobuf.T) in
    let mdio_i = mk_wire 1 in
    let mdio_o = mk_wire 1 in
    let mdio_t = mk_wire 1 in
    let system_i =
      {
        System.I.rst_n = i.rst_n;
        sys_clk = i.sys_clk;
        switches = i.switches;
        uart_rx = i.uart_rx;
        eth_rmii_in = i.eth_rmii_in;
        eth_intn = i.eth_intn;
        eth_mdio_i = { Mdio.I.mdio_i };
      }
    in
    let system_o =
      {
        System.O.leds = o.leds;
        uart_tx = o.uart_tx;
        eth_ref_clk = o.eth_ref_clk;
        eth_rst_n = o.eth_rst_n;
        eth_rmii_out = o.eth_rmii_out;
        eth_mdio_o = { Mdio.O.mdc = o.eth_mdc; mdio_o; mdio_t };
      }
    in
    C_iobuf.inst "IOBUF"
      { Iobuf.I.i = mdio_o; t = mdio_t }
      { Iobuf.O.o = mdio_i }
      { Iobuf.T.io = t.eth_mdio };
    inst
      ~i:(System.I.to_list (System.I.zip System.I.port_names system_i))
      ~o:(System.O.to_list (System.O.zip System.O.port_names system_o))
      (name ^ "_system")
end

let generate_system name (create_fn : create_fn) =
  let module C = Circuit.With_interface (System.I) (System.O) in
  let scope = Scope.create () in
  let circuit = C.create_exn ~name (System.create create_fn scope) in
  let database = Scope.circuit_database scope in
  let buf = Buffer.create 1024 in
  Rtl.output ~database ~output_mode:(Rtl.Output_mode.To_buffer buf)
    Rtl.Language.Verilog circuit;
  Buffer.contents buf

let generate_top name =
  let module C = Structural.With_interface (Top.I) (Top.O) (Top.T) in
  let circuit = C.create_circuit name (Top.create name) in
  let rtl = ref "" in
  Structural.write_verilog (fun s -> rtl := !rtl ^ s) circuit;
  !rtl

let generate name (create_fn : create_fn) =
  let system = generate_system (name ^ "_system") create_fn in
  let top = generate_top name in
  system ^ "\n" ^ top
