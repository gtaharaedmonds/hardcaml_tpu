open Base

type 'a t = 'a Array.t Array.t

let create size ~f =
  Array.init size ~f:(fun row -> Array.init size ~f:(fun col -> f row col))

let get (t : _ t) ~row ~col = t.(row).(col)

let iteri (t : _ t) ~f =
  Array.iteri t ~f:(fun row row_lst ->
      Array.iteri row_lst ~f:(fun col elem -> f row col elem))

let mapi (t : _ t) ~f =
  create (Array.length t) ~f:(fun row col -> get t ~row ~col |> f row col)
