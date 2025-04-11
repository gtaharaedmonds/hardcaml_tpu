open Hardcaml

module I : sig
  type 'a t = { clk_in1 : 'a; resetn : 'a } [@@deriving sexp_of, hardcaml]
end

module O : sig
  type 'a t = {
    locked : 'a;  (** 100 MHz clock *)
    clk_out1 : 'a;  (** 50 MHz clock *)
    clk_out2 : 'a;  (** 50 MHz clock w/ 45deg phase shift *)
    clk_out3 : 'a;
  }
  [@@deriving sexp_of, hardcaml]
end

val create : Signal.t I.t -> Signal.t O.t
