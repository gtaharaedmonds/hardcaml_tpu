open Base
open Hardcaml

let size = 3
let data_bits = 8

module Row = struct
  type 'a t = { elements : 'a list [@bits data_bits] [@length size] }
  [@@deriving hardcaml]
end

type 'a t = { rows : 'a Row.t list [@length size] } [@@deriving hardcaml]

let _create ~f =
  {
    rows =
      List.init size ~f:(fun row ->
          { Row.elements = List.init size ~f:(fun col -> f row col) });
  }

let get t ~row ~col =
  let row_lst = List.nth_exn t.rows row in
  List.nth_exn row_lst.elements col

let iteri t ~f =
  List.iteri t.rows ~f:(fun row row_lst ->
      List.iteri row_lst.elements ~f:(fun col elem -> f row col elem))
