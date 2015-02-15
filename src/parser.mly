/** Autogenerated parser module */

/*  This file contains a Lua LALR(1) grammar suitable for ocamlyacc or menhir 
    (or other yacc-compatible parser generators)

    It was built with inspiration from a Lua 5.1 ANTLR grammar by Nicolai Mainiero
    which utilized ANTLR's backtracking: http://www.antlr3.org/grammar/1178608849736/Lua.g
*/

%{
  (** Autogenerated parser module *)

  module A = Ast

  let unimp msg pos =
    Error.error "Not implemented error" ("LuaTA does not support " ^ msg) pos

  let start_pos = Parsing.symbol_start_pos
  let rhs_pos   = Parsing.rhs_start_pos

  let mk_stmt pos s = { Ast.stmt_pos = pos;
			Ast.stmt     = s }

  let unop op e = A.Unop (op, e)
  let binop l op r = A.Binop (l, op, r)

  let de_table (unnamed, named) =
    A.Lit (A.Table (unnamed, named))

%}

%start chunks
%type <Ast.block> chunks /*chunklist*/

%type <A.lvalue> var
%type <A.stmt list list> statlist

%token EOF
%token COMMA LBRA RBRA LT GT COLON SEMI HAT STAR HASH
%token SLASH MOD LPAR RPAR GETS PLUS MINUS DOT LSQ RSQ 

%token WRONGTOKEN
%token NIL
%token TRUE FALSE
%token IF THEN ELSE ELSEIF WHILE DO REPEAT UNTIL BREAK FOR IN GOTO CASE GLOBMATCH OF END
%token RETURN
%token LOCAL
%token FUNCTION
%token DOTS
%token ARROW
%token <Ast.number> NUMBER
%token <Ast.str> STRING
%token <Ast.str> LONGSTRING
%token <string> NAME 

%token <int> DEBUG_PRAGMA

%token AND OR
%token EQ NE LE GE
%token CONC
%token UNARY NOT


%left OR
%left AND /* was: %left AND OR */
%left EQ NE GT LT LE GE
%right CONC  /* was: %left CONC */
%left PLUS MINUS
%left STAR SLASH MOD
%left NOT HASH UNARY
%right HAT


%% /* beginning of rules section */

chunks   : block EOF { $1 }
         ;

funcname  : funcname_prefix      { fun ((args, v), ss) w ->
                                     if v then unimp "varargs" w
                                     else
				       [mk_stmt w (A.Assign ([$1], [A.Lit (A.Fun (args,ss))]))]  }
          | funcname_prefix COLON NAME { fun ((args, v), ss) w ->
                                     if v then unimp "varargs" w
                                     else
				       [mk_stmt w (A.Assign ([A.Index(A.Lvalue $1,$3)],
							     [A.Lit (A.Fun ("self"::args,ss))]))]
				       }
          ;

funcname_prefix : NAME                      { A.Name $1 }
                | funcname_prefix DOT NAME  { A.Index (A.Lvalue $1, $3) }
                ;

body :  LPAR parlist RPAR block END { let pos = Lexing.dummy_pos (*Parsing.rhs_start_pos 5*) in
				      match List.rev $4 with   (* Add explicit return when absent *)
                                       | []   -> ($2, [mk_stmt pos (A.Return [A.Lit A.Nil])])
				       | s::_ -> (match s.A.stmt with
					   | A.Return _ -> ($2, $4)
					   | _          -> ($2, $4 @ [mk_stmt pos
									 (A.Return [A.Lit A.Nil])])) } ;

statlist : /* empty */                           { [] }
         | SEMI statlist                         { $2 }
         | statlist1_paren                       { $1 }
         | statlist1_no_paren                    { $1 }
         ;

/* Note: statements beginning with a parenthesis  */
/*       are only legal initially or after an explicit SEMI */
/* Invariant: both end with a list of semis, 
              one starts with paren, one doesn't */
statlist1_paren : stat_paren sc_list                     { [$1] }
                | stat_paren sc_list  statlist1_no_paren { $1 :: $3 }
                | stat_paren sc_list1 statlist1_paren    { $1 :: $3 }
                ;

statlist1_no_paren : stat_no_paren sc_list                      { [$1] }
                   | stat_no_paren sc_list1 statlist1_paren     { $1 :: $3 }
                   | stat_no_paren sc_list  statlist1_no_paren  { $1 :: $3 }
                   ;


sc_list  : /* empty */         { () }
         | sc_list1            { () } ;

sc_list1  : SEMI               { () }
          | SEMI sc_list1      { () } ;

sc       : /* empty */         { () }
         | SEMI                { () } ;

stat_paren : LPAR expr1 RPAR colon_name_argslist1 { let pos = start_pos() in
						    let rec build_call recv args = match args with
                                                      | ((None,args),[])        ->
							[mk_stmt pos (A.Callstmt (A.Paren recv,args))]
                                                      | ((Some mname,args),[]) ->
							[mk_stmt pos
 							         (A.Methcallstmt (A.Paren recv,mname,args))]
						      | ((None,fstargs),sndargs::rest) -> 
							build_call (A.Call (A.Paren recv,fstargs))
							           (sndargs,rest)
						      | ((Some mname,fstargs),sndargs::rest) -> 
							build_call (A.Methcall (A.Paren recv,mname,fstargs))
							           (sndargs,rest)
						    in build_call $2 $4 }
           | varlist1_paren GETS exprlist1        { let pos     = start_pos() in
						    let lvals,_ = $1 in
						    let exprs,_ = $3 in 
						    [mk_stmt pos (A.Assign (lvals,exprs))] }
           ;

assign_or_call_no_paren : varlist1_no_paren GETS exprlist1  { let pos     = start_pos() in
							      let lvals,_ = $1 in
							      let exprs,_ = $3 in 
							      [mk_stmt pos (A.Assign (lvals,exprs))] }
                        | valid_funcall_no_paren            { let pos = start_pos() in
							      match $1 with
								| (recv,(None,args)) ->
								  [mk_stmt pos (A.Callstmt (recv,args))]
								| (recv,(Some mname,args)) ->
								  [mk_stmt pos 
								      (A.Methcallstmt (recv,mname,args))] }
			;

/* Invariant: the following two cannot begin with a paren
              the first ends as a valid lvalue (var_no_paren)
              the second ends as a valid invocation  */
              
valid_lvalue_no_paren : NAME                                 { A.Name $1 }
  	  	      | valid_lvalue_no_paren  DOT NAME      { A.Index (A.Lvalue $1,$3) }
  	  	      | valid_lvalue_no_paren  LSQ expr1 RSQ { A.DynIndex (A.Lvalue $1,$3) }
  	  	      | valid_funcall_no_paren DOT NAME      { match $1 with
			                                        | (recv,(None,args)) ->
								  A.Index (A.Call (recv,args), $3)
			                                        | (recv,(Some mname,args)) ->
								  A.Index (A.Methcall (recv,mname,args),$3) }
  	  	      | valid_funcall_no_paren LSQ expr1 RSQ   { match $1 with
			                                          | (recv,(None,args)) ->
								    A.DynIndex (A.Call (recv,args), $3)
			                                          | (recv,(Some mname,args)) ->
								    A.DynIndex
								      (A.Methcall (recv,mname,args), $3) }
                      ;

valid_funcall_no_paren : valid_lvalue_no_paren  colon_name args  { (A.Lvalue $1,($2,$3)) }
                       | valid_funcall_no_paren colon_name args  { match $1 with
			                                            | (recv,(None,args)) ->
								      (A.Call (recv,args), ($2,$3))
			                                            | (recv,(Some mname,args)) ->
								      (A.Methcall (recv,mname,args), ($2,$3))
		       }
                       ;

stat_no_paren  :
         assign_or_call_no_paren    { $1 }
       /* label: missing */
       | BREAK                      { [mk_stmt (start_pos()) A.Break] }
       | GOTO NAME                  { unimp "goto" (start_pos()) }
       | DO block END               { [mk_stmt (start_pos()) (A.Doend $2)] }
       | WHILE expr1 DO block END   { [mk_stmt (start_pos()) (A.WhileDo ($2, $4))] }
       | REPEAT block UNTIL expr1   { unimp "repeat ... until ..." (start_pos()) }
       | IF expr1 THEN block elsepart END { [mk_stmt (start_pos()) (A.If ($2, $4, $5))] }
       | FOR NAME GETS expr1 COMMA expr1 opt_step DO block END
	                            { (* desugaring according to 5.2 manual, sec.3.3.5 'For Statement' *)
				      let for_pos    = start_pos() in
				      let nam_pos    = rhs_pos 2 in
				      let tonum e    = A.Call (A.Lvalue (A.Name "tonumber"),[e]) in
				      let error_call = A.Callstmt (A.Lvalue (A.Name "error"),[]) in
				      let tmpvar     = A.Name "__var" in
				      let tmplimit   = A.Name "__limit" in
				      let tmpstep    = A.Name "__step" in
				      match $7 with
				      | None ->
					[mk_stmt for_pos
					  (A.Doend
					    [mk_stmt nam_pos (A.Local (["__var";"__limit"], [tonum $4;tonum $6]));
					     mk_stmt for_pos (A.If (A.Unop (A.Not,
									    A.And (A.Lvalue tmpvar,
										   A.Lvalue tmplimit)),
								    [mk_stmt for_pos error_call],
								    []));
					     mk_stmt for_pos (A.WhileDo (A.Binop (A.Lvalue tmpvar,
										  A.Le,
										  A.Lvalue tmplimit),
						List.flatten
						  [[mk_stmt nam_pos (A.Local ([$2],[A.Lvalue tmpvar]))];
						   $9;
						   [mk_stmt for_pos (A.Assign ([tmpvar],
									       [A.Binop (A.Lvalue tmpvar,
											 A.Plus,
											 A.Lit (A.Number (A.Int 1)) )])) ]
						  ] )) ]) ]
				      | Some step ->
					[mk_stmt for_pos
					  (A.Doend
					    [mk_stmt nam_pos (A.Local (["__var";"__limit";"__step"],
								       [tonum $4; tonum $6; tonum step]));
					     mk_stmt for_pos (A.If (A.Unop (A.Not,
									    A.And (A.And (A.Lvalue tmpvar,
											  A.Lvalue tmplimit),
										   A.Lvalue tmpstep)),
								    [mk_stmt for_pos error_call],
								    []));
					     mk_stmt for_pos (A.WhileDo
								(A.Or
								   (A.And
								      (A.Binop (A.Lvalue tmpstep,
										A.Gt,
										A.Lit (A.Number (A.Int 0))),
								       A.Binop (A.Lvalue tmpvar,
										A.Le,
										A.Lvalue tmplimit)),
								    A.And
								      (A.Binop (A.Lvalue tmpstep,
										A.Le,
										A.Lit (A.Number (A.Int 0))),
								       A.Binop (A.Lvalue tmpvar,
										A.Ge,
										A.Lvalue tmplimit))),
						 List.flatten
						   [[mk_stmt nam_pos (A.Local ([$2],[A.Lvalue tmpvar]))];
						    $9;
						    [mk_stmt for_pos (A.Assign ([tmpvar],
										[A.Binop (A.Lvalue tmpvar,
											  A.Plus,
											  A.Lvalue tmpstep )]))]
						   ] )) ]) ]
				    }
       | FOR namelist IN exprlist1 DO block END {
	                              let pos       = start_pos() in
				      let fstname,names = $2 in
				      let names_pos = rhs_pos 2 in
				      let exprs,_   = $4 in
				      let exprs_pos = rhs_pos 4 in
				      let body      = $6 in
				      let tmpf      = A.Name "__f" in
				      let tmps      = A.Name "__s" in
				      let tmpvar    = A.Name "__var" in
				      [mk_stmt pos
					  (A.Doend [
					    mk_stmt exprs_pos
					      (A.Local (["__f";"__s";"__var"],exprs));
					    mk_stmt pos
					      (A.WhileDo (A.Lit (A.Bool true),
						mk_stmt names_pos (A.Local (fstname::names, 
									    [A.Call (A.Lvalue tmpf,
										     [A.Lvalue tmps;
										      A.Lvalue tmpvar])]))::
						mk_stmt pos       (A.If (A.Binop (A.Lvalue (A.Name fstname),
										  A.Eq,
										  A.Lit A.Nil),
									 [mk_stmt pos A.Break],[]))::
						mk_stmt pos       (A.Assign ([tmpvar],[A.Lvalue (A.Name fstname)]))::
						body))])]
                                    }
       | FUNCTION funcname body     { $2 $3 (start_pos()) };
       | LOCAL FUNCTION NAME body   { let pos = start_pos() in
				      let ((args,v), ss) = $4 in
				      if v then unimp "varargs" pos
                                      else (*desugar local fun decl into two parts to handle recursion:*) 
					[mk_stmt pos (A.Local ([$3], [A.Lit (A.Nil)]));
					 mk_stmt pos (A.Assign ([A.Name $3], [A.Lit (A.Fun (args,ss))]))] };
       | LOCAL localdeclist decinit { let pos = start_pos() in
				      let locals,_localslen = $2 in
				      let rhs,   _rhslen    = $3 in
				      [mk_stmt pos (A.Local (locals, rhs))] }

elsepart : /* empty */    { [] }
         | ELSE block     { $2 }
         | ELSEIF expr1 THEN block elsepart { [mk_stmt (start_pos()) (A.If ($2, $4, $5))] }

opt_step : /* empty */    { None }
         | COMMA expr1    { Some $2 } 
         ;

block    :  statlist                    { List.flatten $1 }
         |  statlist RETURN exprlist sc { let retpos = rhs_pos 2 in
					  let ret    = mk_stmt retpos (A.Return $3) in
					  List.flatten ($1 @ [[ret]]) }
         ;

expr1    : expr { $1 } ;
                                
expr :
     /* binop */
       expr1 EQ  expr1        { binop $1 A.Eq $3 }
     | expr1 LT  expr1        { binop $1 A.Lt $3 }
     | expr1 GT  expr1        { binop $1 A.Gt $3 }
     | expr1 NE  expr1        { binop $1 A.Ne $3 }
     | expr1 LE  expr1        { binop $1 A.Le $3 }
     | expr1 GE  expr1        { binop $1 A.Ge $3 }
     | expr1 PLUS expr1       { binop $1 A.Plus  $3 }
     | expr1 MINUS expr1      { binop $1 A.Minus $3 }
     | expr1 STAR expr1       { binop $1 A.Times $3 }
     | expr1 SLASH expr1      { binop $1 A.Div   $3 }
     | expr1 MOD expr1        { binop $1 A.Mod   $3 }
     | expr1 HAT expr1        { binop $1 A.Pow   $3 }
     | expr1 CONC expr1       { binop $1 A.Concat $3 }
     | expr1 AND expr1        { A.And ($1,$3) }
     | expr1 OR  expr1        { A.Or ($1,$3) }
     /* unop */
     | MINUS expr1 %prec UNARY  { unop A.Uminus $2 }
     | NOT expr1              { unop A.Not $2 }
     | HASH expr1             { unop A.Length $2 }
     | NIL                    { A.Lit (A.Nil)       }
     | TRUE                   { A.Lit (A.Bool true) }
     | FALSE                  { A.Lit (A.Bool false) }
     | NUMBER                 { A.Lit (A.Number $1) }
     | string                 { $1 }
     /* varargs missing */
     | prefixexp              { $1 }
     | table                  { $1 }
     | FUNCTION body          { let (args,bl) = $2 in
				if snd args
				then unimp "varargs" (start_pos())
				else A.Lit (A.Fun (fst args, bl)) }
     ;

string : STRING               { match $1 with
                                 | A.Normal ns -> A.Lit (A.String (A.Normal (String.escaped ns)))
				 | A.Char cs   -> A.Lit (A.String (A.Char (String.escaped cs)))
				 | A.Long _    -> failwith "Internal string parser inconsistency" }
       | LONGSTRING           { A.Lit (A.String ($1)) }

table : LBRA fieldlist RBRA   { de_table $2 } ;

prefixexp    : NAME                      { A.Lvalue (A.Name $1) }
             | LPAR expr1 RPAR           { A.Paren $2 }
	     | prefixexp colon_name args { match $2 with
		                            | None       -> A.Call ($1, $3)
					    | Some mname -> A.Methcall ($1,mname,$3) }
	     | prefixexp DOT NAME        { A.Lvalue (A.Index ($1,$3)) }
	     | prefixexp LSQ expr1 RSQ   { A.Lvalue (A.DynIndex ($1,$3)) }
             ;

/* invariant: both must end in colon_name args
              one starts with colon_name_args, whereas the other doesn't  */ 

args      :  LPAR exprlist RPAR  { $2 } 
          |  table               { [$1] }
          |  string              { [$1] }
          ;

var       : NAME var_suffix_list              { $2 (A.Name $1) }
          | LPAR expr1 RPAR var_suffix_list1  { $4 (A.Paren $2) }
          ;

var_paren : LPAR expr1 RPAR var_suffix_list1  { $4 (A.Paren $2) }
          ;

/* action function : A.exp -> A.lvalue  */ 
var_suffix : colon_name_argslist DOT NAME       { fun (recv : A.exp) -> 
                                                    let rec build_exp recv args = (match args with
                                                     | [] ->
						       A.Index (recv,$3)
						     | (None,fst)::rest ->
						       build_exp (A.Call (recv,fst)) rest
						     | (Some mname,fst)::rest ->
						       build_exp (A.Methcall (recv,mname,fst)) rest) in
						    build_exp recv $1 }
	   | colon_name_argslist LSQ expr1 RSQ  { fun (recv : A.exp) ->
                                                    let rec build_exp recv args = (match args with
                                                     | []        -> A.DynIndex (recv,$3)
						     | (None,fstargs)::rest ->
						       build_exp (A.Call (recv,fstargs)) rest
						     | (Some mname,fstargs)::rest ->
						       build_exp (A.Methcall (recv,mname,fstargs)) rest) in
						    build_exp recv $1 }
           ;

/* action function : A.lvalue -> A.lvalue  */
var_suffix_list : /* empty */                 { fun (recv : A.lvalue) -> recv }
                | var_suffix_list1            { fun (recv : A.lvalue) -> $1 (A.Lvalue recv) }
		;

/* action function : A.exp -> A.lvalue  */
var_suffix_list1 : var_suffix                   { $1 }
                 | var_suffix_list1 var_suffix  { fun (recv : A.exp) -> $2 (A.Lvalue ($1 recv)) }
		 ;

colon_name_argslist : /* empty */          { [] }
		    | colon_name_argslist1 { let (fst,rest) = $1 in
					     fst::rest }
                    ;

colon_name_argslist1 : colon_name args                      { (($1,$2), []) }
		     | colon_name args colon_name_argslist1 { let (fst,rest) = $3 in
							      (($1,$2), fst::rest) }
                     ;

colon_name : /* empty */  { None }
  	   | COLON NAME   { Some $2 }


/* Original grammar: */ /*
prefixexp    : varexp                    { $1 }
             | functioncall              { let f, es = $1 in A.Call (f, es) }
	     | LPAR expr1 RPAR           { $2 } ;

functioncall : prefixexp args            { ($1,$2) }
             | prefixexp COLON NAME args { unimp "method call" (start_pos()) } ;

args         : LPAR exprlist RPAR        { $2 } 
             | table                     { [$1] }
             | string                    { [$1] } ;

var          : singlevar                 { A.Name $1 }
             | varexp LSQ expr1 RSQ      { A.DynIndex ($1, $3) }
             | varexp DOT NAME           { A.Index ($1, $3) } ;

varexp       : var                       { A.Lvalue $1 } ;

singlevar    : NAME                      { $1 } ;

var_or_exp   : var                       { $1 }
	     | LPAR expr1 RPAR           { $2 } ;
*/


exprlist  :  /* empty */          { [] }
          |  exprlist1            { let es,len = $1 in es }
          ;
                
exprlist1 :  expr                 { ([$1],1) }
          |  exprlist1 COMMA expr { let es,len = $1 in (es @ [$3],len+1) }
          ;

parlist   :  /* empty */          { ([], false) }
          |  DOTS                 { ([], true) }
          |  parlist1 opt_dots    { ($1, $2) }
          ;
                
parlist1  :  par                  { [$1] }
          |  parlist1 COMMA par   { $1 @ [$3] }
          ;

opt_dots  : /* empty */           { false }
          | COMMA DOTS            { true  }

par : NAME      { $1 }
    ;
                
fieldlist  : lfieldlist semicolonpart { ($1, $2) }
           | ffieldlist1 lastcomma    { ([], $1) }
           ;

semicolonpart : /* empty */           { [] }
              | SEMI ffieldlist       { $2 }
              ;

lastcomma  : /* empty */               { () }
           | COMMA                     { () }
           ;

ffieldlist  : /* empty */              { [] }
            | ffieldlist1 lastcomma    { $1 }
            ;   

ffieldlist1 : ffield                   { [$1] }
            | ffieldlist1 COMMA ffield { $1 @ [$3] }
ffield      : NAME GETS expr1          { ($1, $3) } ;

lfieldlist  : /* empty */              { [] }
            | lfieldlist1 lastcomma    { $1 }
            ;

lfieldlist1 : expr1  {[$1]}
            | lfieldlist1 COMMA expr1  { $1 @ [$3] }
            ;

varlist1_paren : var_paren                 { ([$1],1) }
               | varlist1_paren COMMA var  { let rest,len = $1 in (rest @ [$3],len+1) }
               ;

varlist1_no_paren  :   /*var_no_paren*/  
                       valid_lvalue_no_paren        { ([$1],1) }
                   |   varlist1_no_paren COMMA var  { let rest,len = $1 in (rest @ [$3],len+1) }
                   ;
                
namelist  : NAME                       { $1,[] }
	  | namelist COMMA NAME        { let fst,rest = $1 in
					 fst,(rest @ [$3]) }
	  ;

localdeclist : NAME                    { ([$1],1) }
             | localdeclist COMMA NAME { let rest,len = $1 in (rest @ [$3],len+1) }
             ;
                
decinit   : /* empty */    { ([],0) }
          | GETS exprlist1 { $2 }
          ;
          
%%
