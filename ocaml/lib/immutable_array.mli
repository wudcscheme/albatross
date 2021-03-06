type 'a t

val empty: 'a t
val length: 'a t -> int
val elem:   int -> 'a t -> 'a
val put:    int -> 'a -> 'a t -> 'a t
val push:   'a -> 'a t -> 'a t
val push_list: 'a list -> 'a t -> 'a t
val of_list:   'a list -> 'a t
val take:   int -> 'a t -> 'a t
