open Container
open Alba2_common
open Printf
open Gamma

module Term = Term2


let string_of_term (c:t) (t:Term.t): string =
  let module SP = Pretty_printer.String_printer in
  let module PP = Pretty_printer.Make (SP) in
  let module TP = Term_printer.Make (Gamma) (PP) in
  let open PP in
  SP.run 200 (make 30 () >>= TP.print t c)

let string_of_term2 (c:t) (t:Term.t): string =
  let module TP = Term_printer2.Make (Gamma) in
  Pretty_printer2.Layout.pretty 70 (TP.print t c)


let string_of_fixpoint (c:t) (fp:Term.fixpoint): string =
  let module TP = Term_printer2.Make (Gamma) in
  Pretty_printer2.Layout.pretty 70 (TP.print_fixpoint fp c)


(* =============================================

   Key Reduction

   =============================================


   1. (lam x:A. t) a args -> t[x:=a] args



   2. x a args -> t a args

      where t is the definition of x


   3. insp(e,r,cases) a args -> insp(f,r,cases)

      where e -> f


   4. insp(co(i) cargs,r,cases) a args -> case(i) cargs a args


   5. fix(i,fp) args1 a args2 -> fix(i,fp) args1 b args2

      where a -> b and a is decreasing argument for the fixpoint i


   6. fix(i,fp) args1 (co(i) cargs) args2 -> t(i) args1 (co(i) cargs) args2

      where t(i) is the term of the fixpoint i with all fixpoint variables j
   substituted by fix(j,fp).

 *)


let rec key_normal0 (f:Term.t) (args: Term.t list) (c:t)
        : Term.t * Term.t list =
  let key = ref f
  and args = ref args
  and go_on = ref true
  in
  let open Term in
  while !go_on do
    match !key, !args with

    | Sort _, [] ->
       go_on := false

    | Sort s, _ :: _ ->
       assert false (* sorts cannot be applied *)

    | Variable i, hd :: tl when Gamma.has_definition i c ->
       key := Gamma.definition i c

    | Variable _, _ ->
       go_on := false

    | Application (f, a, _), _ ->
       key := f;
       args := a :: !args

    | Lambda _, [] ->
       go_on := false

    | Lambda (_, tp, t), hd :: tl ->
       key := substitute t hd;
       args := tl

    | All _, [] ->
       go_on := false

    | All _, _ :: _ ->
       assert false (* product cannot be applied *)

    | Inspect _, [] ->
       go_on := false

    | Inspect (e, res, cases), _ :: _ ->

       let e, eargs = key_normal0 e [] c
       in
       begin
         match e with

         | Variable i when Gamma.is_constructor i c ->
            key := snd cases.(Gamma.constructor_offset i c);
            args := eargs @ !args

         | _ ->
            key := Inspect (apply_args e eargs, res, cases);
            go_on := false
       end

    | Fix _, [] ->
       go_on := false

    | Fix (i, fp), _ :: _ ->

       let _,_,decr,_ = fp.(i) in
       let args1_rev,args2 =
         Mylist.split_condition (fun i _ -> i = decr) !args
       in

       begin
         match args2 with

         | [] ->
            go_on := false

         | hd :: tl ->
            let co,coargs = key_normal0 hd [] c in

            match co with

            | Variable j when Gamma.is_constructor j c ->
               (* reduce fixpoint *)
               key := Term.reduce_fixpoint i fp;
               args := List.rev args1_rev @ (apply_args co coargs) :: args2

            | _ ->
               (* no reduction, but reinsert key normal form of decreasing
                  argument. *)
               args := List.rev args1_rev @ (apply_args co coargs) :: args2;
               go_on := false
       end
  done;
  !key, !args




let key_normal (t:Term.t) (c:t): Term.t * Term.t list =
  key_normal0 t [] c


let key_normal_term (t:Term.t) (c:t): Term.t =
  let key,args = key_normal0 t [] c in
  Term.apply_args key args







(* ==========================================================

   Equivalence of Terms

   ==========================================================
 *)


let rec equivalent (a:Term.t) (b:Term.t) (c:t): bool =
  (* Are [a] and [b] equivalent (i.e. convertible) in the context [c]?
     Assume that both terms are wellformed. *)
  let ka,argsa = key_normal a c in
  let kb,argsb = key_normal b c in
  equivalent_key ka kb c && equivalent_arguments argsa argsb c


and equivalent_key (a:Term.t) (b:Term.t) (c:t): bool =
  (* Are [a] and [b] equivalent as keys of an application in key normal form
     in the context [c]? Assume that both terms are wellformed. *)
  let open Term in
  match a, b with

  | Sort sa, Sort sb ->
     Sorts.equal sa sb

  | Variable i,  Variable j ->
     i = j

  | Lambda (nme,tpa,ta), Lambda (_,tpb,tb) when equivalent tpa tpb c ->
     equivalent ta tb (push_simple nme tpa c)

  | All (nme,tpa,ta), All (_,tpb,tb) when equivalent tpa tpb c ->
     equivalent ta tb (push_simple nme tpa c)

  | Inspect (ea,pa,casesa), Inspect (eb,pb,casesb)
       when equivalent ea eb c && equivalent pa pa c ->
     let ncases = Array.length casesa in
     assert(ncases <> Array.length casesb);
     interval_for_all
       (fun i ->
         let ca,fa = casesa.(i)
         and cb,fb = casesb.(i) in
         equivalent fa fb c)
       0 ncases

  | Fix _, Fix _ ->
     assert false (* nyi *)

  (* default case: not an application or different constructors *)
  | _ ->
     false

and equivalent_arguments (argsa: Term.t list) (argsb:Term.t list) (c:t)
    : bool =
  match argsa, argsb with
  | [], [] ->
     true
  | a :: argsa, b :: argsb ->
     equivalent a b c && equivalent_arguments argsa argsb c
  | _ ->
     false




let normalize (t:Term.t) (c:t): Term.t =
  t (* nyi BUG!! *)




let rec is_subtype (a:Term.typ) (b:Term.typ) (c:t): bool =
  (* Is [a] a subtype of [b] in the context [c]. Assume that both are
     wellformed.  *)
  let ka,argsa = key_normal a c in
  let kb,argsb = key_normal b c in
  let open Term in
  match ka, kb with
  | Sort sa, Sort sb ->
     Sorts.sub sa sb (sort_variables c)
  | All (nme,tpa,ta), All(_,tpb,tb) ->
     equivalent tpa tpb c
     && is_subtype ta tb (push_simple nme tpa c)
  | _ ->
     equivalent_key ka kb c && equivalent_arguments argsa argsb c







(* ===================================================================

   Decreasing Fixpoints

   ===================================================================


   A recursive call must be protected by one ore more pattern matches of the
   decreasing argument.

   The decreasing argument of the fixpoint term must be of an inductive type
   of a family. A constructor argument is a recursive argument if its type
   belongs to the same family as the constructor.

   In a pattern match [inspect(x,r,[f1,f2,...])] each recursive argument of
   any fi is structurally smaller than x. We expect the inspected expression
   to be a variable.

   The inspect expressions surrounding a recursive call gives the set of all
   variables structurally smaller than the decreasing argument of the fixpoint
   expression.

   For any recursive call [y args] we get the argument expression
   corresponding to the decreasing argument of [y]. This argument expression
   must be structurally smaller than the decreasing formal argument of the
   current fixpoint expression.

   In Coq it is possible to compute a structurally smaller elements of the
   original argument. A smaller accessibility proof term can be computed from
   an acessibility proof term by giving a predecessor in the corresponding
   relation. We do not use this possibility for the time being.

   Having the argument expression of the decreasing argument of the recursive
   call, the key normal form of this expression must have one of the
   structurally smaller variables in the key (i.e. function) position.

   The algorithm holds a set of structurally smaller variables (use De Bruijn
   levels to describe them) during the term iteration. Whenver it encounters a
   recursive call it reduces the argument expression to key normal form and
   searches for the key variable in the set of structurally smaller varibles.

  *)

let check_fixpoint_decreasing
      (t:Term.t) (fp:Term.fixpoint)
      (nargs:int) (decr:int) (c:Gamma.t)
    : unit option =
  (* Check that the component term [t] of the fixpoint array [fp] with [nargs]
     arguments is decreasing on the [decr] argument. The context [c] contains
     all types of the fixpoints and all arguments of the current fixpoint.

     - At least one branch calls another function j of the fixpoint array.

     - A recursive call has the form [(Var j) args b ...] where [b] is the
     decreasing argument of fixpoint j and b is a part of the argument [decr]
     of the current fixpoint.

     Remark:

     - [t] is not an abstraction, all abstractions are already pushed into the
     context.  *)
  assert (decr < nargs);

  let decr_level = (* level of decreasing argument *)
    Gamma.count c - nargs + decr

  and fixpoint_start = (* level of first fixpoint *)
    Gamma.count c - nargs - Array.length fp

  and fixpoint_beyond = (* level beyond last fixpoint *)
    Gamma.count c - nargs
  in

  let decrementing_argument i c =
    (* What is the decrementing argument of a recursive call with variable [i]
       in the function position? Return [None] if variable [i] does not
       represent a component of the fixpoint [fp]. *)
    let level = Gamma.to_level i c in
    if fixpoint_start <= level && level < fixpoint_beyond then
      let _,_,decr,_ = fp.(fixpoint_beyond - level - 1) in
      Some decr
    else
      None

  and can_generate_smaller i smaller c =
    let level = Gamma.to_level i c in
    level = decr_level || IntSet.mem level smaller

  and add_recursive_arguments i j smaller c =
    (* add recursive arguments of the constructor [j] of the inductive type of
       variable [i] to the set of structurally smaller variables. The
       constructor arguments are not yet pushed into the context. Therefore
       the level starts at [Gamma.count c]. *)
    let tp = Gamma.entry_type i c in
    let ivar,args = key_normal0 tp [] c in
    match Gamma.inductive_index ivar c with
    | Some (ind_idx,ind) ->
       let rec_args = Inductive.recursive_arguments ind_idx j ind in
       List.fold_left
         (fun smaller recarg ->
           IntSet.add (Gamma.count c + recarg) smaller
         )
         smaller rec_args
    | None ->
       assert false (* Variable i occurs as the inspected expression. The
                       inspect expression is wellformed, therefore it must be
                       an inductive type. *)
  in

  let rec check (t:Term.t) (smaller:IntSet.t) (c:t) (n:int)
          : int option =
    (* Check all recursive calls in the term [t]. Return the number of valid
       recursive calls or None if there are illegal calls. *)

    let check_with_lambda t smaller c n =
      let t1, c1 = push_lambda t c in
      check t1 smaller c1 n
    in

    let check_list lst n =
      Option.fold_list
        (fun n t _ -> check t smaller c n)
        lst n
    in

    let key,args = key_normal0 t [] c
    in
    let open Term in
    match key with
    | Sort s ->
       assert (args = []); (* sorts cannot be applied *)
       Some n

    | Variable i ->
       begin
         match decrementing_argument i c with

         | Some decr_j ->
            (* [key args] is a recursive call *)
            let args1_rev,args2 =
              Mylist.split_condition (fun k _ -> k = decr_j) args in
            begin
              match args2 with
              | [] ->
                 (* too few arguments in the recursive call *)
                 None
              | hd :: tl ->
                 let hd_key,_ = key_normal0 hd [] c
                 in
                 match hd_key with
                 | Variable i_hd ->
                    if IntSet.mem (Gamma.to_level i_hd c) smaller then
                      (* The argument [hd] is structurally smaller. Now it
                         remains to check the other arguments beside [hd]. The
                         arguments of [hd_key] need not be checked, because
                         the positivity condition guarantees that they do not
                         contain any inductive objects of the same inductive
                         family. *)
                      Option.(check_list args1_rev (n+1)
                              >>= check_list tl)
                    else
                      (* [Variable i_hd] is not structurally smaller *)
                      None
                 | _ ->
                    (* [hd] cannot be structurally smaller *)
                    None
            end

         | None ->
            (* We are not in a recursive call. Therefore check arguments
               only. *)
            check_list args n
       end

    | Application _ ->
       assert false (* key cannot be an application *)

    | Lambda (nme, tp, t) ->
       assert (args = []); (* otherwise [key args] would have a key redex *)
       check t smaller (Gamma.push_simple nme tp c) n

    | All (nme, tp, t) ->
       assert (args = []); (* product cannot be applied *)
       check t smaller (Gamma.push_simple nme tp c) n

    | Inspect (Variable i, res, cases)
         when can_generate_smaller i smaller c ->
       Option.(
        fold_array
          (fun n case j ->
            let smaller = add_recursive_arguments i j smaller c in
            check_with_lambda (snd case) smaller c n
          )
          n cases
       )

    | Inspect (e, res, cases) ->
       Option.(
        check e smaller c n >>= fun n ->
        fold_array
          (fun n case j ->
            check_with_lambda (snd case) smaller c n
          )
          n cases
       )

    | Fix (i_inner, fp_inner) ->
       (* The fixpoint array [fp2] is not interesting per se, but some of its
          components might have recursive calls to some component of the outer
          fixpoint. *)
       let c1 = Gamma.push_fixpoint fp_inner c
       in
       Option.fold_array
         (fun n comp _ ->
           let _,_,_,t = comp in
           check t smaller c1 n)
         n fp_inner
  in

  Option.(
    check t IntSet.empty c 0 >>= fun n ->
    if n = 0 then
      printf "fixpoint element does not contain a recursive call\n%s\n"
        (string_of_term2 c t);
    of_bool (0 < n)
  )







(* ===================================================================

   Type Checking

   ===================================================================

  A collection of mutually recursive functions.

*)

let rec check (t:Term.t) (c:t): Term.typ option =
  (* Return the type of [t] in the context [c] if it is wellformed. *)
  let open Term in
  match t with
  | Sort s ->
     Option.(Sorts.type_of s (count_sorts c) >>= fun s -> Some (Sort s))

  | Variable i ->
     if  i < count c then
       Some (entry_type i c)
     else
       begin
         printf "variable (%d/%d) out of bounds\n" i (count c);
         None
       end

  | Application (f,a,_) ->
     (* Does the type of [a] fit the argument type of [f]? *)
     Option.(
      check f c >>= fun ftp ->
      check a c >>= fun atp ->
      (* Now f,ftp and a,atp are wellformed *)
      let hn = key_normal_term ftp c in
      match hn with
      | All (_, tp, res) (* tp, res are wellformed *)
           when is_subtype atp tp c  ->
         Some (Term.substitute res a)
      | _ ->
         None
     )
  | Lambda (nme,tp,t) ->
     (* check:
        - Is [tp] a wellformed type?
        - Is [t] a wellformed term in the context [c,tp]?
        - Is the corresponding product wellformed? *)
     Option.(
      check tp c >>= fun s ->
      Term.get_sort s
      >> check t (push_simple nme tp c) >>= fun ttp ->
      let lam_tp = All (nme,tp,ttp) in
      check lam_tp c
      >> Some lam_tp
     )
  | All (nme,arg_tp,res_tp) ->
     (* check:
        - Is [arg_tp] must be a wellformed type?
        - Is [res_tp] must be a wellformed type in the context with [c,arg_tp]?

        The sorts of [arg_tp] and [res_tp] determine the sort of the quantified
        expression. *)
     Option.(
      let open Term in
      check arg_tp c >>= fun arg_s ->
      check res_tp (push_simple nme arg_tp c) >>= fun res_s ->
      product arg_s res_s
     )
  | Inspect (e,res,cases) ->
     check_inspect e res cases c
  | Fix (idx, arr) ->
     if idx < 0 || Array.length arr <= idx then
       None
     else
       Option.(
       check_fixpoint arr c
       >> let _,typ,_,_ = arr.(idx) in
          Some typ)


and check_inspect
(e:Term.t) (res:Term.t) (cases:(Term.t*Term.t) array) (c:Gamma.t)
    : Term.typ option =
  (* inspect(e,res,cases)

     1. Compute head normal form of the type of e: I p a
        I must be an inductive type with nparams parameter. Therefore
        parameters and arguments can be extracted.

     2. Compute the type of res(a,e). inspect(e,res,cases): res(a,e).
        If I has an elimination restriction, then the sort of res(a,e) must
        be Proposition.

     3. |cases| = number of constructors of I.

     4. For all 0 <= j < |cases|:

        Compute type of cj(p) where cj is the j-th constructor of I and p are
        the parameters.
            cj(p): all(t:T) I p aj.

        Compute the type of fj = snd cases.(j).
            fj: all(t:T) res(aj,cj(p,t))

   *)
  Option.(
    check e c >>= fun e_tp ->
    check_inductive e_tp c >>= fun (ivar,params,args,ind,ind_idx) ->

    (* The term [res(args,e)] is the result type of the expression, its sort
       must satisfy the potential elimination restrictions of [I]. *)
    let res_tp = Term.apply1 (Term.apply_args res args) e in
    check res_tp c >>= fun res_s ->
    if Inductive.is_restricted ind_idx ind && res_s <> Term.proposition then
      None
    else if Inductive.nconstructors ind_idx ind <> Array.length cases then
      None
    else if
      interval_for_all
        (fun j ->
          let cj, fj = cases.(j) in
          let cj0 =
            Term.apply_args
              (Term.Variable (Gamma.constructor_of_inductive j ivar c))
              params in
          None <>
            (check cj0 c >>= fun _ ->
             check cj  c >>= fun cj_tp ->
             check_case cj cj_tp fj res c
            )
        )
        0 (Array.length cases)
    then
      Some res_tp
    else
      None
  )


and check_inductive (tp:Term.typ) (c:t)
    : (Term.t           (* I *)
       * Term.t list    (* params *)
       * Term.t list    (* args *)
       * Inductive.t
       * int            (* ind_idx *)
      ) option =
  Option.(
    let ivar,args = key_normal0 tp [] c in
    Gamma.inductive_index ivar c >>= fun (ind_idx,ind) ->
    let nparams = Inductive.nparams ind in
    let params,args = Mylist.split_at nparams args in
    Some (ivar,params,args,ind,ind_idx)
  )


and check_case
(cj:Term.t) (* fst cases.(j) *)
(cj_tp:Term.typ) (* type of cj *)
(fj:Term.t) (* snd cases.(j) *)
(res:Term.t)
(c:Gamma.t)
    : unit option =
  (* - cp and cj must have an equivalent type
     - cj: all(t:T) I p aj, fj: all(t:T) res(aj,cj(t))
   *)
  let rec split_product c_tp f_tp i c =
    match c_tp, f_tp with
    | Term.All(nm1,tp1,c_tp), Term.All(_,tp2,f_tp) when equivalent tp1 tp2 c ->
       split_product c_tp f_tp (i+1) (Gamma.push_simple nm1 tp1 c)
    | _ ->
       Some (c_tp,f_tp,i,c)
  in
  Option.(
    check fj c >>= fun fj_tp ->
    split_product cj_tp fj_tp 0 c >>= fun (i_tp,res_tp,n,c1) ->
    check_inductive i_tp c1 >>= fun (ivar,params,args,ind,ind_idx) ->
    let res_tp_req =
      Term.apply1
        (Term.apply_args (Term.up n res) args)
        (Term.apply_standard n 0 (Term.up n cj))
    in
    check res_tp_req c1 >>= fun _ ->
    if equivalent res_tp_req res_tp c1 then
      Some ()
    else
      None
  )

and check_fixpoint (fp:Term.fixpoint) (c:Gamma.t): unit option =
  (* - All types must be valid in the current environment
     - All terms must have the corresponding type
     - All recursive calls must be with a structurally decreasing argument *)
  let len = Array.length fp in
  Option.(
    (* Check all types and push them into the context. *)
    fold_array
      (fun ci element i ->
        let nme,typ,decr,t = element in
        check typ c
        >> Some (Gamma.push nme (Term2.up i typ) ci)
      )
      c fp
    >>= fun c1 -> (* Now c1 contains all types of the [len] fixpoints. *)
    (* Now check all fixpoints that they have the correct type and are
       structurally decreasing. *)
    interval_fold
      (fun _ i ->
        let nme,typ,decr,t = fp.(i) in
        check t c1 >>= fun tp ->
        of_bool (equivalent tp (Term.up len typ) c1)
        >>
          (* fixpoint [i] has the correct type. *)
          let t2,c2 = Gamma.push_lambda t c1 in
          let nargs = Gamma.count c2 - Gamma.count c1 in
          of_bool (decr < nargs)
          >> check_inductive
               (Gamma.entry_type (nargs - decr - 1) c2) c2
          >>= fun (_,_,_,ind,_) ->
          check_fixpoint_decreasing t2 fp nargs decr c2
      )
      (Some ()) 0 len
  )



let check_with_sort (t:Term.t) (c:t): (Term.typ*Term.typ) option =
  Option.(
    check t c >>= fun tp ->
    check tp c >>= fun s ->
    Some (tp,s)
  )


let is_wellformed (t:Term.t) (c:t): bool =
  check t c <> None


let is_wellformed_type (tp:Term.t) (c:t): bool =
  Option.(
    check tp c >>= fun s ->
    Term.get_sort s
  ) <> None





let check_inductive (ind:Inductive.t) (c:t): Inductive.t option =
  (* Are all parameter types are valid? *)
  let check_parameter (c:t): t option =
    let np = Inductive.nparams ind in
    let rec checki i c =
      if i = np then
        Some c
      else
        let nme,tp = Inductive.parameter i ind in
        if is_wellformed tp c then
          checki (i+1) (push (some_feature_name_opt nme) tp c)
        else
          None
    in
    checki 0 c
  in
  (* Are all inductive types arities of some sort? *)
  let check_types (c:t): unit option =
    let ni = Inductive.ntypes ind in
    let rec checki i =
      if i = ni then
        Some ()
      else
        let _,tp = Inductive.itype0 i ind in
        let tp = normalize tp c in
        Option.(
          check tp c >>= fun s ->
          Term.get_sort s (* BUG, we need the inner sort!!! *)
          >> checki (i+1)
        )
    in
    checki 0
  in
  let is_positive_cargs (i:int) (j:int) (c:t): bool =
    let cargs = Inductive.cargs i j ind
    and ni = Inductive.ntypes ind
    and np = Inductive.nparams ind
    and cr = ref c in
    let indvar m v =
      m + np <= v && v < m + np + ni
    in
    try
      for k = 0 to Array.length cargs - 1 do
        let nme,tp = cargs.(k) in
        if Term.has_variables (indvar k) tp then
          begin
              let tp = normalize tp !cr in
              let tpargs,tp0 = Term.split_product tp in
              let ntpargs = Array.length tpargs in
              let f,args = Term.split_application tp0 [] in
              let args = Array.of_list args in
              let nargs = Array.length args in
              assert (np <= nargs);
              if
                (* if the k-th argument is a function, then none of its
                   arguments contains an inductive type *)
                interval_for_all
                   (fun l ->
                     not (Term.has_variables
                            (indvar (k+l))
                            (snd tpargs.(l)))
                   )
                   0 ntpargs
                (* The final term constructs an inductive type *)
                && Term.has_variables (indvar (k+ntpargs)) f
                (*(* The first inductive arguments are the parameters *)
                && interval_for_all
                     (fun l ->
                       args.(l) = Term.Variable (k+np-1-l))
                     0 np*)
                (* The remaining arguments do not contain any inductive type
                 *)
                && interval_for_all
                     (fun l ->
                       not (Term.has_variables (indvar (k+ntpargs)) args.(l))
                     )
                     np nargs
              then
                ()
              else
                raise Not_found
          end;
        cr := push (some_feature_name_opt nme) tp !cr
      done;
      true
    with Not_found ->
      false
  in
  let check_constructors (c:t): unit option =
    try
      let cc = Gamma.push_ind_types_params ind c in
      for i = 0 to Inductive.ntypes ind - 1 do
        for j = 0 to Inductive.nconstructors i ind - 1 do
          let nme,tp = Inductive.ctype0 i j ind in
          if is_wellformed_type tp cc
             && Inductive.is_valid_iargs i j ind
             && is_positive_cargs i j cc
          then
            ()
          else
            raise Not_found
        done
      done;
      Some ()
    with Not_found ->
      None
  in
  Option.(
    check_parameter c >>= fun cp ->
    check_types cp
    >> check_constructors c
    >> Some ind
  )








(* Some builtin types and functions *)
(* -------------------------------- *)


(* Predicate (A:Any): Any := A -> Proposition *)
let predicate (sv0:int): Gamma.Definition.t =
  let open Term in
  let v0 = sort_variable sv0 in
  let t = Lambda (Some "A", v0, arrow variable0 proposition)
  and typ = All (Some "A", v0, v0) in
  Definition.make_simple (Some "Predicate") typ t []


(* Relation (A,B:Any): Any := A -> Proposition *)
let binary_relation (sv0:int): Gamma.Definition.t =
  let open Term in
  let v0 = sort_variable sv0
  and v1 = sort_variable (sv0+1) in
  let t = Lambda
            (Some "A",v0,
             Lambda
               (Some "B",v1,
                arrow variable1 (arrow variable0 proposition)))
  and typ = All
              (Some "A",
               v0,
               All
                 (Some "B",
                  v1,
                  product1 v0 v1))
  in
  Definition.make_simple (Some "Relation") typ t []


(* Endo_relation (A:Any): Any := Relation(A,A) *)
let endorelation (sv0:int) (rel_idx:int) (rel_sv0:int): Definition.t =
  let open Term in
  let t =
    Lambda
      (Some "A",
       sort_variable sv0,
       apply_args (Variable (rel_idx+1)) [variable0;variable0])
  and typ =
    All
      (Some "A",
       sort_variable sv0,
       product1 (sort_variable rel_sv0) (sort_variable (rel_sv0+1)))
  in
  Definition.make_simple (Some "Endorelation") typ t
    [(sv0,rel_sv0,false); (sv0,rel_sv0+1,false)]




(* pred0 (a:Natural): Natural :=
        inspect
            a
        case
            0 := 0
            n.successor := n
        end
 *)
let nat_pred0 (nat_idx:int): Gamma.Definition.t =
  assert (2 <= nat_idx);
  let open Term in
  let nat_tp = Variable nat_idx
  and nat_succ = Variable (nat_idx - 2)
  and nat_zero = Variable (nat_idx - 1)
  in
  let nme = some_feature_operator Operator.Plusop
  and typ = arrow nat_tp nat_tp
  in
  let t =
    Lambda(
        (Some "a"),
        nat_tp,
        Inspect (
            variable0,
            Lambda (None, up 1 nat_tp, up 2 nat_tp),
            [|up 1 nat_zero, up 1 nat_zero;
              Lambda(Some "n", up 1 nat_tp, apply1 (up 2 nat_succ) variable0),
              Lambda(Some "n", up 1 nat_tp, variable0)
            |]))
  in
  Gamma.Definition.make nme typ t []


(* (+)(a,b:Natural): Natural :=
       inspect a case
           0 := b
           n.successor := n + b.successor
       end
 *)
let nat_add_fp (nat_idx:int): Term.fixpoint =
  assert (2 <= nat_idx);
  let open Term in
  let nat_tp = Variable nat_idx
  and nat_zero = Variable (nat_idx - 1)
  and nat_succ = Variable (nat_idx - 2)
  in
  let nme = some_feature_operator Operator.Plusop
  and typ =
    arrow nat_tp (arrow nat_tp nat_tp)
  in
  let t =
    lambda
      [Some "a", up 1 nat_tp;
       Some "b", up 2 nat_tp]
      (Inspect( (* inner context has 3 variables: (+) a b *)
           variable1,
           Lambda (None, up 3 nat_tp, up 4 nat_tp),
           [| up 3 nat_zero,
              variable0;

              Lambda(Some "n", up 3 nat_tp, apply1 (up 4 nat_succ) variable0),
              Lambda (Some "n",
                      up 3 nat_tp,
                      apply2
                        variable3
                        variable0
                        (apply1 (up 4 nat_succ) variable1))
           |]
      ))
  in
  [|nme,typ,0,t|]







(* Test **********************************)

let print_type_of (t:Term.t) (c:t): unit =
  match check t c with
  | None ->
     printf "not wellformed %s\n" (string_of_term c t);
  | Some tp ->
     printf "%s : %s\n" (string_of_term c t) (string_of_term c tp)

let test (): unit =
  let equal_opt a b =
    match a with
    | None ->
       false
    | Some a ->
       Term.equal a b
  in
  let equivalent_opt a b c =
    match a with
    | None ->
       false
    | Some a ->
       equivalent a b c
  in
  Printf.printf "test type checker\n";
  let open Term in
  let c = push_unnamed datatype
            (push_sorts 2 [0,1,false] empty) in
  let c1 = push_unnamed variable0 c in
  assert ( is_wellformed (sort_variable 0) c);
  assert ( is_wellformed (sort_variable 1) c);
  assert ( check (sort_variable 0) c = Some (sort_variable_type 0));
  assert ( check (sort_variable 2) c = None);
  assert ( check variable0 c = Some datatype);
  assert ( check variable1 c1 = Some datatype);
  assert ( is_wellformed variable0 c1);
  assert ( check variable0 c1 = Some variable1);
  assert
    begin
      Option.( check_with_sort variable0 c1 >>= fun (_,s) ->
               Some s
      ) = Some datatype
    end;

  (* Proposition -> Proposition *)
  assert ( check (arrow proposition proposition) c = Some any1);

  (* Natural -> Proposition *)
  assert ( check (arrow variable0 proposition) c = Some any1);

  (* (Natural -> Proposition) -> Proposition **)
  assert ( check (arrow
                    (arrow variable0 proposition)
                    proposition) c = Some any1);

  (* all(A:Prop) A -> A : Proposition *)
  assert ( product proposition proposition = Some proposition );
  assert ( product datatype proposition    = Some proposition );
  assert ( check (All (None,
                       proposition,
                       arrow variable0 variable0)) c
           = Some proposition);

  (* all(n:Natural) n -> n is illformed, n is not a type! *)
  assert ( check (All (None,
                       Variable 0,
                       arrow variable0 variable0)) c
           = None);

  (* Natural -> Natural : Datatype *)
  assert ( product datatype datatype    = Some datatype );
  assert ( check (arrow variable0 variable0) c
           = Some datatype);

  (* ((A:Prop,p:A) := p): all(A:Prop) A -> A *)
  assert ( check
             (Lambda (None,
                      proposition,
                      Lambda (None,
                              variable0,
                              variable0)
                ))
             c
           = Some (All (None,
                        proposition,
                        arrow variable0 variable0) )
    );

  (* All prover type:
         all(p:Proposition) p: Proposition
     is equivalent to false *)
  assert( check (All (Some "p", proposition, variable0)) empty
          = Some proposition);

  (* All inhabitor type:
         all(p:SV0) p:  SV0'
     is equivalent to false *)
  assert( check (All (Some "T", sort_variable 0, variable0)) c
          = Some (sort_variable_type 0));

  assert (check_inductive Inductive.make_natural empty <> None);
  assert (check_inductive Inductive.make_false empty <> None);
  assert (check_inductive Inductive.make_true empty <> None);
  assert (check_inductive Inductive.make_and empty <> None);
  assert (check_inductive Inductive.make_or empty <> None);
  assert (check_inductive (Inductive.make_equal 0) c <> None);
  assert (check_inductive (Inductive.make_list 0) c <> None);
  assert (check_inductive (Inductive.make_accessible 0) c <> None);

  (* class Natural create 0; successor(Natural) end *)
  ignore(
      let ind = Inductive.make_natural
      in
      assert (check_inductive ind empty <> None);
      let c = push_inductive ind empty in
      assert (check variable2 c = Some datatype);
      assert (check variable1 c = Some variable2);
      assert (check variable0 c = Some (arrow variable2 variable2))
    );


  (* Failed positivity:
     class C create
         _ (f:C->C): C
     end
   *)
  assert
    begin
      let ind =
        Inductive.make_simple
          (some_feature_name "C") [||] datatype
          [| Inductive.Constructor.make
               None [| None, arrow variable0 variable0 |] [||] |]
      in
      check_inductive ind empty = None
    end;


  (* Predicate, Relation, Endorelation *)
  assert
    begin
      let d = predicate 0 in
      equal_opt
        (check (Definition.term d) c)
        (Definition.typ d)
    end;
  assert
    begin
      let d = binary_relation 0 in
      equal_opt
        (check (Definition.term d) c)
        (Definition.typ d)
    end;
  begin
    let endo = endorelation 2 0 0 in
    let c =
      (push_sorts 3 (Definition.constraints endo) empty)
      |> push_definition (binary_relation 0)
    in
    assert (equal_opt (check (Definition.term endo) c) (Definition.typ endo));
    let c =
      push_definition endo c
      |> push_simple (Some "Natural") datatype in
    (* Endorelation(Natural) *)
    let endo_nat = Application(variable1,variable0,false) in
    (*print_type_of endo_nat c;*)
    assert (is_wellformed endo_nat c)
  end;

  (* Predecessor and addition of natural numbers *)
  begin
    let ind = Inductive.make_natural
    in
    let c = push_inductive ind empty in
    let pred = nat_pred0 2 in
    printf "%s\n" (string_of_term2 c (Definition.term pred));
    assert (is_wellformed (Definition.term pred) c);
    assert (equivalent_opt
              (check (Definition.term pred) c)
              (Definition.typ pred)
              c);
    let plus_fp = nat_add_fp 2 in
    printf "%s\n" (string_of_fixpoint c plus_fp);
    assert (check_fixpoint plus_fp c <> None)
  end;
  ()
