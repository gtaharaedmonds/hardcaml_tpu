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

  let of_list lst =
    create ~f:(fun row col ->
        let row_lst = List.nth_exn lst row in
        List.nth_exn row_lst col)

  let pp t to_string =
    (* get dimensions *)
    let num_rows = List.length t.rows in

    if Int.equal num_rows 0 then Stdio.printf "[empty matrix]\n"
    else
      (* get column widths for alignment *)
      let first_row = List.hd_exn t.rows in
      let num_cols = List.length first_row.elements in
      let col_widths = Array.create ~len:num_cols 0 in

      (* calculate max width for each column *)
      List.iter t.rows ~f:(fun row ->
          List.iteri row.elements ~f:(fun col_idx elem ->
              let str = to_string elem in
              let len = String.length str in
              col_widths.(col_idx) <- Int.max col_widths.(col_idx) len));

      (* calculate total width for horizontal borders *)
      let total_width =
        Array.sum (module Int) col_widths ~f:Fn.id + (3 * (num_cols - 1)) + 2
      in
      let spacer = String.make (total_width - 2) '-' in

      (* Print each row *)
      Stdio.printf "┌─%s─┐\n" spacer;

      List.iter t.rows ~f:(fun row ->
          Stdio.printf "│ ";
          List.iteri row.elements ~f:(fun col_idx elem ->
              let str = to_string elem in
              Stdio.printf "%s" str;

              (* add padding *)
              let padding = col_widths.(col_idx) - String.length str in
              if padding > 0 then Stdio.printf "%s" (String.make padding ' ');

              (* add separator between columns *)
              if col_idx < List.length row.elements - 1 then Stdio.printf " │ ");
          Stdio.printf " │\n");

      Stdio.printf "└─%s─┘\n" spacer
end

let%expect_test "matrix_pp_test" =
  let open Make (struct
    let bits = 8
    let size = 3
  end) in
  let t = create ~f:(fun row col -> ((row * 3) + col + 1) * 10) in
  pp t Int.to_string;
  [%expect
    {|
    ┌─------------─┐
    │ 10 │ 20 │ 30 │
    │ 40 │ 50 │ 60 │
    │ 70 │ 80 │ 90 │
    └─------------─┘
    |}]
