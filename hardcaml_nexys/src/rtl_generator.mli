open Base
open Hardcaml

val generate :
  (Scope.t -> Signal.t User_app.I.t -> Signal.t User_app.O.t) ->
  Rtl.Output_mode.t ->
  unit
