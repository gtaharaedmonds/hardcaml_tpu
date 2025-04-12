open! Base
open! Hardcaml

module I = struct
  type 'a t = {
    rst_n : 'a;
    ref_clk : 'a;
    mii_out : 'a Mii.O.t; [@rtlprefix "mac2rmii_"]
    rmii_in : 'a Rmii.I.t; [@rtlprefix "phy2rmii_"]
  }
  [@@deriving sexp_of, hardcaml]
end

module O = struct
  type 'a t = {
    mii_in : 'a Mii.I.t; [@rtlprefix "rmii2mac_"]
    rmii_out : 'a Rmii.O.t; [@rtlprefix "rmii2phy_"]
  }
  [@@deriving sexp_of, hardcaml]
end

let create (input : _ I.t) =
  let module Inst = Instantiation.With_interface (I) (O) in
  Inst.create ~name:"tpu_nexys_mii_to_rmii_0_0" input
