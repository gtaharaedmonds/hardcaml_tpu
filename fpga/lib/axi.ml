open! Base
open! Hardcaml
open! Hardcaml_axi

module Config = struct
  let addr_bits = 32
  let data_bits = 32
end

include Hardcaml_axi.Lite.Make (Config)
