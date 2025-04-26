open Base
open Hardcaml

module type S = sig
  module Matrix : Matrix.S

  module I : sig
    type 'a t = { clock : 'a; reset : 'a; load : 'a; data : 'a Matrix.t }
    [@@deriving hardcaml]
  end

  module O : sig
    type 'a t = { wavefront : 'a list } [@@deriving hardcaml]
  end

  val create :
    ?name:string ->
    ?hierarchical:bool ->
    Scope.t ->
    transpose:bool ->
    Signal.t I.t ->
    Signal.t O.t
end

module type Triangular_wavefront = sig
  module type S = S

  module Make (Matrix : Matrix.S) : S with module Matrix := Matrix
end
