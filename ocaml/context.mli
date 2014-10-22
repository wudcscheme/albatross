(* Copyright (C) Helmut Brandl  <helmut dot brandl at gmx dot net>

   This file is distributed under the terms of the GNU General Public License
   version 2 (GPLv2) as published by the Free Software Foundation.
 *)

(** Context with stacked declarations of formal arguments *)


open Signature
open Support
open Term
open Container

type t
val make:  unit -> t

val module_table: t -> Module_table.t
val class_table: t  -> Class_table.t
val feature_table:t -> Feature_table.t

val current_module:     t -> int
val used_modules:       int -> t -> IntSet.t
val add_used_module:    (int * int list) -> IntSet.t -> t -> unit
val add_current_module: int -> IntSet.t -> t -> unit
val set_interface_check: IntSet.t -> t -> unit

val is_private:        t -> bool
val is_public:         t -> bool
val is_interface_check:t -> bool
val is_interface_use:  t -> bool
    (** Are we using an interface? *)


val find_module:        (int * int list) -> t -> int

val push_with_gap:  entities list withinfo -> return_type -> int -> t -> unit
val push:  entities list withinfo -> return_type -> t -> unit
val push_untyped: int array -> t -> unit
val pop:   t -> unit
val print: t -> unit

val is_global:   t -> bool
val is_toplevel: t -> bool
val depth:       t -> int
val arity:     t -> int
val argument:  int -> t -> int * Tvars.t * Sign.t

val result_type: t -> type_term

val count_type_variables: t -> int
    (** The number of cumulated type variables in this context and all
        preceeding contexts *)

val count_local_type_variables: t -> int
    (** The number of type variables in this context without all preceeding
        contexts *)

val count_formal_generics: t -> int
    (** The number of formal generics in this context and all preceeding
        contexts *)

val count_last_arguments:  t -> int
    (** The number of formal arguments in this context without the preceeding
        contexts *)

val count_arguments:  t -> int
    (** The number of formal arguments in this context and all preceeding
        contexts *)

val argument_name: int -> t -> int
    (** The name of the [i]th formal argument *)

val argument_type: int -> t -> type_term
    (** The type of the [i]th formal argument *)

val fgnames: t   -> int array
val local_fargnames: t -> int array

val ith_arguments_string: int -> t -> string

val type_variables: t -> TVars_sub.t
    (** The type variables and their substitutions *)

val boolean: t -> term

val update_type_variables: TVars_sub.t -> t -> unit

val string_of_term:       term -> int -> t -> string
val string_of_term_outer: term -> int -> t -> string
val sign2string:    Sign.t -> t -> string
val signature_string: t -> string
val named_signature_string: t -> string


val owner:          t -> int
val check_deferred: t -> unit

val find_identifier: int ->          int -> t -> (int * Tvars.t * Sign.t) list
val find_feature:    feature_name -> int -> t -> (int * Tvars.t * Sign.t) list

val put_global_function:
    feature_name withinfo  -> Feature_table.implementation_status ->
      term option -> t -> unit

val implication_id: t -> int

val put_formal_generic: int withinfo -> type_t withinfo -> t -> unit

val print_local_contexts:       t -> unit

val expanded_term:  term -> t -> term
