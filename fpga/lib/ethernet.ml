open! Base
open! Hardcaml
open! Signal

(* The AXI Ethernet Lite IP unfortunately has a slightly different interface
than other IP blocks I'm using. So this module serves as glue to match the
ethernet IP.
Specifically: AXI doesn't have prot lines, MII signals have different names. *)
module Ip = struct
  module Axi = struct
    module Master_to_slave = struct
      type 'a t = {
        awaddr : 'a; [@bits 13]
        awvalid : 'a;
        wdata : 'a; [@bits 32]
        wstrb : 'a; [@bits 32 / 8]
        wvalid : 'a;
        bready : 'a;
        araddr : 'a; [@bits 13]
        arvalid : 'a;
        rready : 'a;
      }
      [@@deriving sexp_of, hardcaml]
    end

    module Slave_to_master = struct
      type 'a t = {
        awready : 'a;
        wready : 'a;
        bresp : 'a; [@bits 2]
        bvalid : 'a;
        arready : 'a;
        rdata : 'a; [@bits 32]
        rresp : 'a; [@bits 2]
        rvalid : 'a;
      }
      [@@deriving sexp_of, hardcaml]
    end
  end

  module Mii = struct
    module I = struct
      type 'a t = {
        col : 'a;
        crs : 'a;
        rx_clk : 'a;
        dv : 'a;
        rx_er : 'a;
        rx_data : 'a; [@bits 4]
        tx_clk : 'a;
      }
      [@@deriving sexp_of, hardcaml]
    end

    module O = struct
      type 'a t = { tx_en : 'a; tx_data : 'a [@bits 4] }
      [@@deriving sexp_of, hardcaml]
    end
  end

  module I = struct
    type 'a t = {
      s_axi_aresetn : 'a;
      s_axi_aclk : 'a;
      axi_m2s : 'a Axi.Master_to_slave.t; [@rtlprefix "s_axi_"]
      mii_in : 'a Mii.I.t; [@rtlprefix "phy_"]
      mdio_i : 'a Mdio.I.t; [@rtlprefix "phy_"]
    }
    [@@deriving sexp_of, hardcaml]
  end

  module O = struct
    type 'a t = {
      axi_s2m : 'a Axi.Slave_to_master.t; [@rtlprefix "s_axi_"]
      ip2intc_irpt : 'a;
      phy_rst_n : 'a;
      mii_out : 'a Mii.O.t; [@rtlprefix "phy_"]
      mdio_o : 'a Mdio.O.t; [@rtlprefix "phy_"]
    }
    [@@deriving sexp_of, hardcaml]
  end
end

module I = struct
  type 'a t = {
    s_axi_aresetn : 'a;
    s_axi_aclk : 'a;
    axi_m2s : 'a Axi.Master_to_slave.t;
    mii_in : 'a Mii.I.t;
    mdio_i : 'a Mdio.I.t;
  }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = {
    axi_s2m : 'a Axi.Slave_to_master.t;
    ip2intc_irpt : 'a;
    phy_rst_n : 'a;
    mii_out : 'a Mii.O.t;
    mdio_o : 'a Mdio.O.t;
  }
  [@@deriving sexp_of, hardcaml]
end

let create (i : _ I.t) =
  let ip_in =
    {
      Ip.I.s_axi_aresetn = i.s_axi_aresetn;
      s_axi_aclk = i.s_axi_aclk;
      axi_m2s =
        {
          Ip.Axi.Master_to_slave.awaddr = i.axi_m2s.awaddr.:[12, 0];
          awvalid = i.axi_m2s.awvalid;
          wdata = i.axi_m2s.wdata;
          wstrb = i.axi_m2s.wstrb;
          wvalid = i.axi_m2s.wvalid;
          bready = i.axi_m2s.bready;
          araddr = i.axi_m2s.araddr.:[12, 0];
          arvalid = i.axi_m2s.arvalid;
          rready = i.axi_m2s.rready;
        };
      mii_in =
        {
          Ip.Mii.I.col = i.mii_in.col;
          crs = i.mii_in.crs;
          rx_clk = i.mii_in.rx_clk;
          dv = i.mii_in.rx_dv;
          rx_er = i.mii_in.rx_er;
          rx_data = i.mii_in.rxd;
          tx_clk = i.mii_in.tx_clk;
        };
      mdio_i = i.mdio_i;
    }
  in
  let module Inst = Instantiation.With_interface (Ip.I) (Ip.O) in
  let ip = Inst.create ~name:"tpu_nexys_axi_ethernetlite_0_0" ip_in in
  {
    O.axi_s2m =
      {
        Axi.Slave_to_master.awready = ip.axi_s2m.awready;
        wready = ip.axi_s2m.wready;
        bresp = ip.axi_s2m.bresp;
        bvalid = ip.axi_s2m.bvalid;
        arready = ip.axi_s2m.arready;
        rdata = ip.axi_s2m.rdata;
        rresp = ip.axi_s2m.rresp;
        rvalid = ip.axi_s2m.rvalid;
      };
    ip2intc_irpt = ip.ip2intc_irpt;
    phy_rst_n = ip.phy_rst_n;
    mii_out =
      { Mii.O.txd = ip.mii_out.tx_data; tx_er = gnd; tx_en = ip.mii_out.tx_en };
    mdio_o = ip.mdio_o;
  }
