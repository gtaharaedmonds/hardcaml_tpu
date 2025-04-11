open Base
open Hardcaml

val generate :
  string ->
  (Scope.t -> Signal.t App.I.t -> Signal.t App.O.t) ->
  Rtl.Output_mode.t ->
  unit
