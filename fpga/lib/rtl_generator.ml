open! Base
open! Hardcaml

(* I don't think Hardcaml.Signal supports tri-state logic? (Which I need for
MDIO to configure the PHY!) So I've made a "nexys" module, which has basically
the entire design and uses Hardcaml.Signal, and a wrapper "top" module which
instantiates the tri-state buffer. The top uses Hardcaml.Structural instead
which supports tri-state logic. *)

type create_fn = Scope.t -> Signal.t App.I.t -> Signal.t App.O.t

module Nexys = struct
  module I = struct
    type 'a t = {
      rst_n : 'a;
      sys_clk : 'a;
      switches : 'a; [@bits 8]
      uart_rx : 'a;
      eth_rmii : 'a Rmii.I.t;
      eth_intn : 'a;
      eth_mdio : 'a Mdio.I.t;
    }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      leds : 'a; [@bits 8]
      uart_tx : 'a;
      eth_ref_clk : 'a;
      eth_rst_n : 'a;
      eth_rmii : 'a Rmii.O.t;
      eth_mdio : 'a Mdio.O.t;
    }
    [@@deriving sexp_of, hardcaml]
  end

  let create (create_fn : create_fn) scope (i : _ I.t) =
    let open Signal in
    let bd =
      Tpu_bd.create
        {
          sys_clk = i.sys_clk;
          rst_n = i.rst_n;
          uart_rx = i.uart_rx;
          gpio_i = i.switches;
          eth_rmii = i.eth_rmii;
          eth_mdio = i.eth_mdio;
        }
    in
    let app =
      App.hierarchical create_fn scope
        { clock = bd.s_axi_aclk; reset = ~:(bd.s_axi_aresetn) }
    in
    ignore app;
    {
      O.leds = bd.gpio_o;
      uart_tx = bd.uart_tx;
      eth_ref_clk = bd.eth_refclk;
      eth_rst_n = bd.eth_rst_n;
      eth_rmii = bd.eth_rmii;
      eth_mdio = bd.eth_mdio;
    }
end

module Top = struct
  module I = struct
    type 'a t = {
      rst_n : 'a;
      sys_clk : 'a;
      switches : 'a; [@bits 8]
      uart_rx : 'a;
      eth_rmii : 'a Rmii.I.t; [@rtlprefix "eth_rmii_"]
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
      eth_rmii : 'a Rmii.O.t; [@rtlprefix "eth_rmii_"]
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
    let nexys_i =
      {
        Nexys.I.rst_n = i.rst_n;
        sys_clk = i.sys_clk;
        switches = i.switches;
        uart_rx = i.uart_rx;
        eth_rmii = i.eth_rmii;
        eth_intn = i.eth_intn;
        eth_mdio = { Mdio.I.mdio_i };
      }
    in
    let nexys_o =
      {
        Nexys.O.leds = o.leds;
        uart_tx = o.uart_tx;
        eth_ref_clk = o.eth_ref_clk;
        eth_rst_n = o.eth_rst_n;
        eth_rmii = o.eth_rmii;
        eth_mdio = { Mdio.O.mdc = o.eth_mdc; mdio_o; mdio_t };
      }
    in
    inst
      ~i:(Nexys.I.to_list (Nexys.I.zip Nexys.I.port_names nexys_i))
      ~o:(Nexys.O.to_list (Nexys.O.zip Nexys.O.port_names nexys_o))
      (name ^ "_nexys");
    C_iobuf.inst "IOBUF"
      { Iobuf.I.i = mdio_o; t = mdio_t }
      { Iobuf.O.o = mdio_i }
      { Iobuf.T.io = t.eth_mdio }
end

let generate_nexys name (create_fn : create_fn) =
  let module C = Circuit.With_interface (Nexys.I) (Nexys.O) in
  let scope = Scope.create () in
  let circuit = C.create_exn ~name (Nexys.create create_fn scope) in
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
  let nexys = generate_nexys (name ^ "_nexys") create_fn in
  let top = generate_top name in
  nexys ^ "\n" ^ top
