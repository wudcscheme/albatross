%{

let parse_error str = !Support.parse_error_fun str

open Support

let filename ()    =  (symbol_start_pos ()).Lexing.pos_fname
let symbol_info () =  info_from_position (symbol_start_pos ())
let rhs_info i     =  info_from_position (rhs_start_pos i)

let cinfo (i:info) =  info_string (filename ()) i

%}

%token KWCURRENT KWCurrent
%token KWNONE
%token KWPrecursor KWProcess
%token KWResult

%token KWall       KWand
%token KWcase      KWclass        KWcheck      KWcreate
%token KWdeferred  KWdo
%token KWelse      KWelseif       KWend        KWensure
%token KWfeature
%token KWghost
%token KWif        KWimmutable    KWin         KWinspect
       KWinvariant
%token KWlocal
%token KWnot       KWnote
%token KWor
%token KWrequire
%token KWthen

%token ARROW
%token ASSIGN
%token BAR
%token CARET
%token COLON
%token COMMA
%token DARROW
%token DBAR
%token DCOLON
%token DIVIDE
%token DOT
%token EOF
%token EQ
%token EQV
%token EXCLAM
%token GE
%token GT
%token HIGHEST_PREC
%token LBRACE
%token LBRACKET
%token LE
%token LPAREN
%token LT
%token LOWEST_PREC
%token MINUS
%token NEQ
%token NEQV
%token NEWLINE
%token NOTIN
%token PLUS
%token QMARK
%token RBRACE
%token RBRACKET
%token RPAREN
%token SEMICOL
%token TIMES
%token UMINUS
%token USCORE

%token <int>    UIDENTIFIER
%token <int>    LIDENTIFIER
%token <int>    OPERATOR
%token <int>    ROPERATOR
%token <string> NUMBER


/*  0 */ %nonassoc LOWEST_PREC  KWghost
/*  5 */ %nonassoc ASSIGN
/* 10 */ %right    COMMA     SEMICOL
/* 15 */ %right    COLON
/* 20 */ %right    ARROW     DARROW
/* 25 */ %left     KWand     KWor
/* 35 */ %left     EQ        NEQ       EQV     NEQV
                   LE        LT        GE      GT
/* 40 */ %left     BAR       DBAR
/* 45 */ %left     PLUS      MINUS
/* 50 */ %left     TIMES     DIVIDE
/* 55 */ %right    CARET     DCOLON
/* 60 */ %left     OPERATOR
/* 61 */ %right    ROPERATOR
/* 65 */ %nonassoc KWnot
/* 80 */ %nonassoc LPAREN    LBRACKET
/* 90 */ %nonassoc UMINUS
/*100 */ %nonassoc HIGHEST_PREC

%start main
%type <Support.module_t> main

%%



main:module_nt { $1 }

module_nt:
    { empty_module }
|   module_nt optsemi declaration { $1 }
|   module_nt declaration_block KWend { $1 }


/* ------------------------------------------------------------------------- */
/* Declaration blocks */
/* ------------------------------------------------------------------------- */

declaration_block: block_type visibility optsemi declarations {()}

block_type:
    KWfeature   { () }
|   KWcreate    { () }
|   KWinvariant { () }


visibility:
    {()}
|   LBRACE KWNONE RBRACE {()}

declarations:
    %prec LOWEST_PREC {()}
|   declarations optsemi declaration {()}


declaration:
    class_declaration {()}
|   named_feature     {()}
|   assertion_feature {()}
|   formal_generic    {()}



/* ------------------------------------------------------------------------- */
/* Formal generics */
/* ------------------------------------------------------------------------- */

formal_generic:
  UIDENTIFIER COLON type_nt { withinfo (rhs_info 1) $1, 
                              withinfo (rhs_info 3) $3 }



/* ------------------------------------------------------------------------- */
/* Classes and types */
/* ------------------------------------------------------------------------- */



header_mark:
  { No_hmark }
| KWimmutable { Immutable_hmark }
| KWcase      { Case_hmark }
| KWdeferred  { Deferred_hmark  }




class_declaration:
  header_mark KWclass UIDENTIFIER actual_generics 
  class_blocks
  KWend {
  {hmark= withinfo (rhs_info 1) $1; cname=withinfo (rhs_info 3) $3}
}


class_blocks:
    {()}
|   class_blocks declaration_block {()}




path:
  { [] }
| LIDENTIFIER DOT path { $1::$3 }


type_nt:
  simple_type  { $1 }
| current_type { $1 }
| arrow_type   { $1 }
| ghost_type   { $1 }
| tuple_type   { $1 }


type_list:
  type_nt { [$1]}
| type_nt COMMA type_list {
  $1::$3
}


actual_generics:
    %prec LOWEST_PREC {[]}
|   LBRACKET type_list RBRACKET { $2 }



simple_type: 
    path UIDENTIFIER actual_generics { Normal_type ($1,$2,$3)}

current_type: KWCURRENT actual_generics { Current_type $2 }


arrow_type: type_nt ARROW type_nt {
  Arrow_type ($1,$3)
}


ghost_type: KWghost type_nt { Ghost_type $2 }


tuple_type: LBRACKET type_list RBRACKET { Tuple_type $2 }






/* ------------------------------------------------------------------------- */
/* Features */
/* ------------------------------------------------------------------------- */


assertion_feature:
    KWall formal_arguments optsemi block_list KWend {
  Printf.printf "Formal arguments: %s\n" (string_of_formals $2);
}



named_feature: 
    nameorop formal_arguments rettype optsemi block_list_opt {
  Printf.printf "Formal arguments: %s\n" (string_of_formals $2);
}

nameorop:
    operator {()}
|   LIDENTIFIER {()}
|   LIDENTIFIER EXCLAM {()}


rettype:
    {()}
|   COLON type_nt {()}

block_list_opt:
    %prec LOWEST_PREC {()}
|   block_list KWend {()}

block_list:
    block  {()}
|   block_list block {()}


block:
    require_block  {()}
|   ensure_block   {()}
|   proof_block    {()}
|   note_block     {()}
|   KWdeferred     {()}


require_block:
    KWrequire assertions {()}

proof_block:
    KWcheck assertions {()}

note_block:
    KWnote compound {()}

ensure_block:
    KWensure assertions {()}

assertions: compound {
  Printf.printf "\n%scompound: %s\n"  
    (cinfo (rhs_info 1))
    (string_of_expression $1);
  match $1 with
    Expcompound l ->
      List.iter 
        (fun el -> 
          Printf.printf "%s exp: %s\n" (cinfo el.i) (string_of_expression el.v))
        l
  | _ -> assert false
}



formal_arguments:
    { [] }
|   LPAREN expression RPAREN {
  try
    formals_from_expression $2
  with
    _ -> 
      Printf.eprintf 
        "%s \"%s\" is not an argument list\n" 
        (cinfo (rhs_info 2))
        (string_of_expression $2);
      failwith "Parse error"
}


/* ------------------------------------------------------------------------- */
/* Flow control */
/* ------------------------------------------------------------------------- */

conditional:
    KWif then_part_list else_part KWend { Expif ($2,$3) }

then_part_list:
    then_part { [$1] }
|   then_part KWelseif then_part_list  { $1::$3 }

then_part:
    expression KWthen compound { withinfo (rhs_info 1) $1, $3 }

else_part:
    { None }
|   KWelse compound { Some $2 }



inspect:
    KWinspect expression case_list KWend {
  Expinspect (withinfo (rhs_info 2) $2, $3)
}

case_list:
    case_part { [$1] }
|   case_part case_list { $1::$2}

case_part:  KWcase expression KWthen expression {
  (withinfo (rhs_info 2) $2), (withinfo (rhs_info 4) $4)
}


/* ------------------------------------------------------------------------- */
/* Expressions */
/* ------------------------------------------------------------------------- */


compound: compound_list { Expcompound $1 }

compound_list:
    { [] }
|   info_expression { [$1] }
|   info_expression SEMICOL compound_list { $1::$3 }


info_expression: expression { withinfo (rhs_info 1) $1 }

expression:
    uexp %prec COMMA { $1 }

|   uexp COLON expression { Taggedexp ($1,$3) }

|   expression COMMA expression {
  match $3 with
    Explist l -> Explist ($1::l)
  | _ -> Explist [$1;$3]
}




uexp:
    atomic_expression           { $1 }

|   uexp PLUS uexp   { Binexp (Plusop,$1,$3) }

|   uexp MINUS uexp  { Binexp (Minusop,$1,$3) }

|   MINUS uexp       { Unexp (Minusop,$2) }

|   uexp TIMES uexp  { Binexp (Timesop,$1,$3) }

|   uexp DIVIDE uexp { Binexp (Divideop,$1,$3) }

|   uexp CARET  uexp { Binexp (Caretop,$1,$3) }

|   uexp EQ  uexp    { Binexp (Eqop,$1,$3) }

|   uexp LT  uexp    { Binexp (LTop,$1,$3) }

|   uexp LE  uexp    { Binexp (LEop,$1,$3) }

|   uexp GT  uexp    { Binexp (GTop,$1,$3) }

|   uexp GE  uexp    { Binexp (GEop,$1,$3) }

|   uexp KWand  uexp { Binexp (Andop,$1,$3) }

|   uexp KWor   uexp { Binexp (Orop,$1,$3)  }

|   KWnot   uexp     { Unexp (Notop,$2) }

|   uexp DCOLON uexp { Binexp (DColonop,$1,$3) }

|   uexp BAR  uexp   { Binexp (Barop,$1,$3) }

|   uexp DBAR uexp   { Binexp (DBarop,$1,$3) }

|   uexp ARROW  uexp { Binexp (Arrowop,$1,$3) }

|   uexp DARROW uexp { Binexp (DArrowop,$1,$3) }

|   uexp COLON type_nt     { Typedexp ($1,$3) }

|   uexp ASSIGN uexp { Expassign ($1,$3) }




atomic_expression:
    LIDENTIFIER                    { Identifier $1 }

|   KWResult                       { ExpResult }

|   NUMBER                         { Number $1 }

|   KWCurrent                      { ExpCurrent }

|   LPAREN expression RPAREN       { Expparen $2 }

|   LPAREN operator RPAREN         { Expop $2 }

|   LBRACKET expression RBRACKET   { Expbracket $2 }

|   LBRACE  expression RBRACE      { Expset $2 }

|   atomic_expression LPAREN expression RPAREN     { Funapp ($1,$3) }

|   atomic_expression LBRACKET expression RBRACKET { Bracketapp ($1,$3) }

|   conditional { $1 }

|   inspect     { $1 }


operator:
    PLUS      { Plusop }
|   MINUS     { Minusop }
|   TIMES     { Timesop }
|   DIVIDE    { Divideop }
|   EQ        { Eqop }
|   EQV       { Eqvop }
|   NEQ       { NEqop }
|   NEQV      { NEqvop }
|   LT        { LTop }
|   LE        { LEop }
|   GT        { GTop }
|   GE        { GEop }
|   CARET     { Caretop }
|   KWand     { Andop }
|   KWor      { Orop }
|   KWnot     { Notop }
|   BAR       { Barop }
|   DBAR      { DBarop }
|   ARROW     { Arrowop }
|   DARROW    { DArrowop }
|   DCOLON    { DColonop }
|   OPERATOR  { Freeop $1 }
|   ROPERATOR { RFreeop $1 }
|   LBRACKET RBRACKET {Bracketop}



/* ------------------------------------------------------------------------- */
/*  General rules  */
/* ------------------------------------------------------------------------- */



optsemi:
    %prec LOWEST_PREC {()}
|   optsemi SEMICOL {()}
