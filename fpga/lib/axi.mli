open! Base
open! Hardcaml
open! Hardcaml_axi
module Config : Bus_config
include module type of Lite.Make (Config)
