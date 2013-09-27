open Support
open Container


type term =
    Variable    of int
  | Application of term * term array
  | Lam         of int * term


module TermSet = Set.Make(struct
  let compare = Pervasives.compare
  type t = term
end)

module TermMap = Map.Make(struct
  let compare = Pervasives.compare
  type t = term
end)






module Term: sig

  val to_string: term -> string

  val nodes: term -> int

  val depth: term -> int

  val split_variables: term -> int -> IntSet.t * IntSet.t

  val free_variables: term -> int -> IntSet.t

  val bound_variables: term -> int -> IntSet.t

  val map: (int->int->term) -> term -> term

  val upbound: int->int->term->term

  val up: int->term->term

  val sub:   term -> term array -> int -> term

  val apply: term -> term array -> term

  val reduce: term -> term

  val unify: term -> int -> term -> int ->  term array * int list

  val binary_split: term -> int -> term * term

  val binary_right: term -> int -> term list

end = struct

  let rec to_string (t:term): string =
    match t with
      Variable i -> string_of_int i
    | Application (f,args) ->
        let fstr = to_string f
        and argsstr = Array.to_list (Array.map to_string args)
        in
        fstr ^ "(" ^
        (String.concat "," (List.rev argsstr))
        ^ ")"
    | Lam(nargs,t) ->
        let args = Array.init nargs (fun i -> (string_of_int (nargs-1-i))) in
        let argsstr = String.concat "," (Array.to_list args) in
        "([" ^ argsstr ^ "]->" ^ (to_string t) ^ ")"




  let rec nodes (t:term): int =
    (* The number of nodes in the term t *)
    match t with
      Variable _ -> 1
    | Application (f,args) ->
        (Array.fold_left (fun sum t -> sum + (nodes t)) (nodes f) args)
    | Lam (_,t) ->
        1 + (nodes t)


  let rec depth (t:term): int =
    (* The depth of the term t *)
    match t with
      Variable _ -> 0
    | Application (f,args) ->
        Mylist.sum depth (1 + (depth f)) (Array.to_list args)
    | Lam (_,t) ->
        1 + (depth t)



  let split_variables (t:term) (nb:int): IntSet.t * IntSet.t =
    (* The set of bound variables strictly below 'n' and above 'n'
       in the term 't' *)
    let rec bfvars t nb bset fset =
      match t with
        Variable i ->
          if i<nb then
            (IntSet.add i bset), fset
          else
            bset, (IntSet.add i fset)
      | Application (f,args) ->
          let fbset,ffset = bfvars f nb bset fset
          and asets = Array.map (fun t -> bfvars t nb bset fset) args
          in
          Array.fold_left
            (fun (cum_bset,cum_fset) (bset,fset) ->
              IntSet.union cum_bset bset,
              IntSet.union cum_fset fset)
            (fbset,ffset)
            asets
      | Lam (nargs,t) ->
          bfvars t (nb+nargs) bset fset
    in
    bfvars t nb IntSet.empty IntSet.empty


  let free_variables (t:term) (nb:int): IntSet.t =
    (* The set of free variables above 'n' in the term 't' *)
    let _,fvars = split_variables t nb
    in
    fvars



  let bound_variables (t:term) (nb:int): IntSet.t =
    (* The set of bound variables strictly below 'n' in the term 't' *)
    let bvars,_ = split_variables t nb
    in
    bvars



  let map (f:int->int->term) (t:term): term =
    (* Map all variables 'j' of the term 't' to 'f j nb' where 'nb' is the
       number of bound variables in the context where 'j' appears
     *)
    let rec mapr nb t =
      match t with
        Variable j -> f j nb
      | Application (a,b) ->
          Application (mapr nb a, Array.map (fun t -> mapr nb t) b)
      | Lam (nargs,t) ->
          Lam(nargs, mapr (nb+nargs) t)
    in
    mapr 0 t





  let upbound (n:int) (start:int) (t:term): term =
    (* Shift all free variables up by 'n' from 'start' on in the term 't' *)
    map
      (fun j nb ->
        if j<nb+start then Variable(j)
        else Variable(j+n))
      t




  let up (n:int) (t:term): term =
    (* Shift all free variables up by 'n' in the term 't' *)
    upbound n 0 t




  let sub (t:term) (args:term array) (nbound:int): term =
    (* substitute the free variables 0,1,args.len-1 in term t by the
       arguments which are from an environment with 'nbound' bound variables,
       i.e. all free variables above 'len' are shifted up by 'nbound-args.len'
     *)
    let len = Array.length args in
    map
      (fun j nb ->
        if j<nb then
          Variable(j)
        else
          let jfree = j-nb in
          if jfree < len then
            args.(jfree)
          else
            Variable(j + nbound - len)
      )
      t




  let apply (t:term) (args: term array): term =
    (* Reduce (beta reduction) the term ([v0,v1,...]->t)(a0,a1,...) i.e.
       apply the function ([v0,v1,...]->t) to the arguments in args
     *)
    sub t args 0





  let rec reduce (t:term): term =
    (* Do all possible beta reductions in the term 't' *)
    let app (f:term) (args: term array): term =
      match f with
        Lam(nargs,t) ->
          assert (nargs=(Array.length args));
          apply t args
      | _ -> Application (f,args)
    in
    match t with
      Variable _ -> t
    | Application (f,args) ->
        let fr = reduce f
        and argsr = Array.map reduce args
        in
        app fr argsr
    | Lam(nargs,t) ->
        let tred = reduce t in
        if 0 < nargs then
          Lam (nargs, tred)
        else
          tred




  let unify (t1:term) (nb1:int) (t2:term) (nb2:int)
      : term array * int list =
    (* Find a substitution (i.e. an array of arguments) for the nb2 bound
       variables of the term t2 so that t1 = Lam(nb2,t2) (args). Clearly the
       size of args must be nb2. The term t1 is in an environment with nb1
       bound variables.

       The second return parameter is the list of variables which do not
       occur in t2 (i.e. a subset of {0,1,...,nb2-1}).
     *)
    let args  = Array.make nb2 t1
    and flags = Array.make nb2 false
    in
    let notfound_unless (cond:bool): unit =
      if cond then () else raise Not_found
    in
    let rec uni (t1:term) (t2:term): unit =
      match t1,t2 with
        _, Variable i2 ->
          if i2<nb2 then
            begin
              if not flags.(i2) then
                (args.(i2) <- t1;
                 flags.(i2) <- true)
              else
                notfound_unless (args.(i2)=t1)
            end
          else begin
            match t1 with
              Variable i1 ->
                notfound_unless ((i1-nb1) = (i2-nb2))
            | _ -> raise Not_found
          end
      | Application (f1,args1), Application (f2,args2) ->
          let l1,l2 = Array.length args1, Array.length args2 in
          if l1=l2 then begin
            uni f1 f2;
            Array.iteri (fun i e -> uni e args2.(i)) args1
          end
          else
            raise Not_found
      | Lam(l1,u1), Lam(l2,u2) ->
          if l1=l2 then
            uni u1 u2
          else
            raise Not_found
      | _ -> raise Not_found
    in
    uni t1 t2;
    assert (t1 = (sub t2 args nb1));
    let arbitrary: int list ref = ref []
    in
    Array.iteri
      (fun i flag ->
        if flag then ()
        else arbitrary := i::!arbitrary )
      flags;
    args,!arbitrary


  let binary_split (t:term) (binid:int): term * term =
    match t with
      Application (f,args) when (Array.length args) = 2 ->
        (match f with
          Variable i when i=binid ->
            (args.(1), args.(0))
        | _ -> raise Not_found)
    | _ -> raise Not_found

  let binary_right (t:term) (binid:int): term list =
    let rec binr (t:term) (lst:term list): term list =
      match t with
        Application (f,args) when Array.length args = 2 ->
          begin
            match f with
              Variable i when i = binid ->
                args.(1) :: lst
            | _ -> lst
          end
      | _ -> []
    in
    binr t []
end


module Term_sub: sig
  type t
  val to_string:   t -> string
  val count:       t -> int
  val is_identity: t -> bool
  val is_permutation: t -> bool
  val empty:       t
  val singleton:   int -> term -> t
  val find:        int -> t -> term
  val mem:         int -> t -> bool
  val add:         int -> term -> t -> t
  val merge:       t -> t -> t
end = struct
  type t = term IntMap.t

  let to_string (sub:t): string =
    let lst = IntMap.fold
        (fun i t lst -> ((string_of_int i)^"->"^(Term.to_string t))::lst
        )
        sub
        []
    in
    "{" ^ (String.concat "," (List.rev lst)) ^ "}"

  let count (sub:t): int =
    IntMap.fold
      (fun i _ sum -> sum+1)
      sub
      0

  let for_all (f: int -> term -> bool) (sub:t): bool =
    IntMap.fold (fun i t res -> res && f i t) sub true

  let is_identity (sub:t): bool =
    for_all (fun i t -> Variable i = t) sub
    (*IntMap.fold (fun i t is_id -> is_id && Variable i = t) sub true *)

  let is_permutation (sub:t): bool =
    try
      let inverse =
        IntMap.fold
          (fun i t map ->
            match t with
              Variable j ->
                IntMap.add j i map
            | _ -> raise Not_found)
          sub
          IntMap.empty
      in
      for_all
        (fun i t ->
          match t with
            Variable j -> (IntMap.find j inverse) = i
          | _ -> assert false)
        sub
    with Not_found -> false


  let empty = IntMap.empty

  let singleton (i:int) (t:term): t =
    IntMap.add i t IntMap.empty

  let find (i:int) (sub:t): term =
    IntMap.find i sub

  let mem (i:int) (sub:t): bool =
    IntMap.mem i sub

  let add (i:int) (t:term) (sub:t): t =
    assert (not (mem i sub));
    IntMap.add i t sub

  let merge (sub1:t) (sub2:t): t =
    let res = ref sub2 in
    IntMap.iter
      (fun i t1 ->
        let t2_opt =
          try Some (IntMap.find i sub2)
          with Not_found -> None
        in
        match t2_opt with
          None ->
              res := IntMap.add i t1 !res
        | Some t2 ->
            if t1=t2 then ()
            else raise Not_found
      )
      sub1;
    !res
end


type substitution = Term_sub.t
