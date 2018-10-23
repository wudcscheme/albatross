include Monad.MONAD with type 'a t = 'a option

val has: 'a t -> bool
val value: 'a t -> 'a
val of_bool: bool -> unit t
val iter:  ('a -> unit) -> 'a t -> unit

val fold_interval: ('a->int->'a t) -> 'a -> int -> int -> 'a t


val fold_list: ('a->'b->int->'a t) -> 'b list -> 'a -> 'a t
(** [fold_list f lst start] folds the function [f] over the list [lst] with
   start value [start].

   The function [f] maps an element of type ['a], an element of the list with
   its position in the list into an element of type ['a].  *)



val fold_array: ('a->'b->int->'a t) -> 'a -> 'b array -> 'a t
(** [fold_array f start arr] folds the function [f] over the array [arr] with
   start value [start].

   The function [f] maps an element of type ['a], an element of the array with
   its position in the array into an element of type ['a].  *)




module Within (M:Monad.MONAD): Monad.MONAD with type 'a t = 'a t M.t
