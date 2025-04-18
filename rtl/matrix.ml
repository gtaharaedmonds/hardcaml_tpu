open Base
open Hardcaml
include Matrix_intf

module Make (Config : Config) = struct
  module Config = Config

  module Row = struct
    type 'a t = { elements : 'a list [@bits Config.bits] [@length Config.size] }
    [@@deriving hardcaml]
  end

  type 'a t = { rows : 'a Row.t list [@length Config.size] }
  [@@deriving hardcaml]

  let create ~f =
    {
      rows =
        List.init Config.size ~f:(fun row ->
            { Row.elements = List.init Config.size ~f:(fun col -> f row col) });
    }

  let get t ~row ~col =
    let row_lst = List.nth_exn t.rows row in
    List.nth_exn row_lst.elements col

  let iteri t ~f =
    List.iteri t.rows ~f:(fun row row_lst ->
        List.iteri row_lst.elements ~f:(fun col elem -> f row col elem))

  let mapi t ~f = create ~f:(fun row col -> get t ~row ~col |> f row col)
end
