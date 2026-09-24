%{
open Ast
%}

/* Token declarations */
%token PROGRAM_START PROGRAM_END
%token VAR_DECL VAR_INIT
%token PRINT PRINT_INLINE PRINT_NEWLINE READ
%token ASSIGN_START ASSIGN_OP ASSIGN_END
%token IF ELSE ELSE_IF END_IF SWITCH CASE DEFAULT END_SWITCH
%token WHILE END_WHILE FOR FOR_FROM FOR_TO FOR_STEP FOR_IN
%token FUNC_DECL FUNC_RETURNS FUNC_PARAMS FUNC_END ELLIPSIS
%token FUNC_CALL FUNC_CALL_ASSIGN RETURN LAMBDA
%token PLUS MINUS MULTIPLY DIVIDE MODULO
%token EQUAL NOT_EQUAL GREATER LESS GREATER_EQUAL
%token AND OR NOT
%token BIT_AND BIT_OR BIT_XOR BIT_SHIFT_LEFT BIT_SHIFT_RIGHT BIT_NOT
%token TO_FIXED FROM_FIXED
%token TRUE FALSE
%token LPAREN RPAREN COMMA
%token IMPORT IMPORT_AS SLASH
%token ARRAY_DECL
%token ARRAY_INDEX
%token TRY
%token CATCH
%token THROW
%token NULL
%token BREAK
%token CONTINUE
%token CLASS
%token EXTENDS
%token NEW
%token STRUCT
%token END_STRUCT
%token NEW_STRUCT
%token UNION
%token END_UNION
%token NEW_UNION
%token ENUM
%token END_ENUM
%token POINTER_REF
%token POINTER_DEREF
%token POINTER_ADDR
%token POINTER_STEP_FORWARD
%token POINTER_STEP_BACK
%token LBRACKET RBRACKET
%token <string> IDENTIFIER
%token <int> INTEGER
%token <float> FLOAT
%token <string> STRING
%token EOF

/* Type declarations */
%type <Ast.expr> expression logical_expr bitwise_expr comparison_expr arith_expr term factor
%type <Ast.stmt> statement var_decl array_decl print_stmt read_stmt assign_stmt
%type <Ast.stmt> if_stmt while_stmt func_call_stmt func_call_with_assign
%type <Ast.stmt> return_stmt try_stmt throw_stmt
%type <Ast.function_decl> function_decl
%type <Ast.class_decl> class_decl
%type <Ast.struct_decl> struct_decl
%type <Ast.union_decl> union_decl
%type <Ast.enum_decl> enum_decl
%type <Ast.top_level_decl> import_stmt
%type <Ast.top_level_decl> top_level_decl

/* Start symbol */
(* "RETURN W MORDĘ JEŻA f()" = zwróć f(), a nie pusty return + wywołanie *)
%nonassoc RETURN_BARE
%nonassoc FUNC_CALL

%start <Ast.program> program

%%

/* ============ PROGRAM ============ */

program:
  | PROGRAM_START decls=list(top_level_decl) PROGRAM_END EOF
    { { declarations = decls } }
  ;

top_level_decl:
  | i=import_stmt { i }
  | s=statement { Statement s }
  | f=function_decl { FunctionDecl f }
  | c=class_decl { ClassDecl c }
  | st=struct_decl { StructDecl st }
  | u=union_decl { UnionDecl u }
  | e=enum_decl { EnumDecl e }
  ;

/* ============ IMPORTS ============ */

import_stmt:
  | IMPORT path=import_path { Import path }
  | IMPORT path=import_path IMPORT_AS alias=IDENTIFIER { ImportAs (path, alias) }
  ;

import_path:
  | id=IDENTIFIER { id }
  | base=IDENTIFIER SLASH rest=import_path { base ^ "/" ^ rest }
  ;

/* ============ STATEMENTS ============ */

(* Każda instrukcja pamięta plik i linię - do komunikatów błędów wykonania *)
statement:
  | s=statement_kind
    { Located ($startpos.Lexing.pos_fname, $startpos.Lexing.pos_lnum, s) }
  ;

statement_kind:
  | v=var_decl { v }
  | a=array_decl { a }
  | p=print_stmt { p }
  | r=read_stmt { r }
  | a=assign_stmt { a }
  | i=if_stmt { i }
  | s=switch_stmt { s }
  | w=while_stmt { w }
  | f=func_call_stmt { f }
  | f=func_call_with_assign { f }
  | r=return_stmt { r }
  | t=try_stmt { t }
  | t=throw_stmt { t }
  | BREAK { Break }
  | CONTINUE { Continue }
  ;

var_decl:
  | VAR_DECL id=IDENTIFIER VAR_INIT e=expression
    { VarDecl (id, e) }
  ;

array_decl:
  | ARRAY_DECL id=IDENTIFIER VAR_INIT LBRACKET exprs=separated_list(COMMA, expression) RBRACKET
    { ArrayDecl (id, exprs) }
  ;

print_stmt:
  | PRINT e=expression { Print e }
  (* JEDZIEM Z TYM ŚLEDZIEM - bez końca linii; NO TO ENTER - sam koniec linii *)
  | PRINT_INLINE e=expression { PrintInline e }
  | PRINT_NEWLINE { Print (StringLiteral "") }
  ;

read_stmt:
  | READ id=IDENTIFIER { Read id }
  ;

assign_stmt:
  | ASSIGN_START arr=array_access_expr ASSIGN_OP e=expression ASSIGN_END
    { ArrayAssign (arr, e) }
  | ASSIGN_START id=IDENTIFIER ASSIGN_OP e=expression ASSIGN_END
    { Assign (id, e) }
  ;

array_access_expr:
  | id=IDENTIFIER LBRACKET idx=expression RBRACKET
    { ArrayAccess (Identifier id, idx) }
  | arr=array_access_expr LBRACKET idx=expression RBRACKET
    { ArrayAccess (arr, idx) }
  ;

if_stmt:
  | IF cond=expression then_block=list(statement) rest=if_rest
    { If (cond, then_block, rest) }
  ;

(* AAA TO ZMIENIA POSTAĆ RZECZY = else if: zagnieżdżony If w gałęzi else, z własną linią *)
if_rest:
  | END_IF { None }
  | ELSE else_block=list(statement) END_IF { Some else_block }
  | ELSE_IF cond=expression block=list(statement) rest=if_rest
    { Some [Located ($startpos.Lexing.pos_fname, $startpos.Lexing.pos_lnum, If (cond, block, rest))] }
  ;

(* CO TO JE x / JAK JE a, b / A JAK NIC Z TEGO / KONIEC GADANIA - zamieniane od razu na łańcuch if:
   wartość raz do zmiennej pomocniczej, przypadek = równość z którąkolwiek z wartości.
   Interpreter i kompilator dostają ten sam kod. ponytail: zmienna pomocnicza nazwana od numeru
   linii - dwa CO TO JE w jednej linii by się pogryzły *)
switch_stmt:
  | SWITCH e=expression cases=list(switch_case) default=option(switch_default) END_SWITCH
    { let file = $startpos.Lexing.pos_fname in
      let tmp = Printf.sprintf "(co to je %d)" $startpos.Lexing.pos_lnum in
      let test vals =
        let eq v = ComparisonOp (Identifier tmp, Equal, v) in
        List.fold_left (fun acc v -> LogicalOp (acc, Or, eq v)) (eq (List.hd vals)) (List.tl vals) in
      let rec chain = function
        | [] -> default
        | (vals, body, line) :: rest -> Some [Located (file, line, If (test vals, body, chain rest))] in
      If (BoolLiteral true, VarDecl (tmp, e) :: Option.value (chain cases) ~default:[], None) }
  ;

switch_case:
  | CASE vals=separated_nonempty_list(COMMA, expression) body=list(statement)
    { (vals, body, $startpos.Lexing.pos_lnum) }
  ;

switch_default:
  | DEFAULT body=list(statement) { body }
  ;

while_stmt:
  | WHILE cond=expression body=list(statement) END_WHILE
    { While (cond, body) }
  | FOR var=IDENTIFIER FOR_FROM a=expression FOR_TO b=expression body=list(statement) END_WHILE
    { For (var, a, b, None, body) }
  | FOR var=IDENTIFIER FOR_FROM a=expression FOR_TO b=expression FOR_STEP k=expression body=list(statement) END_WHILE
    { For (var, a, b, Some k, body) }
  | FOR var=IDENTIFIER FOR_IN coll=expression body=list(statement) END_WHILE
    { ForEach (var, coll, body) }
  ;

func_call_stmt:
  | FUNC_CALL id=IDENTIFIER LPAREN args=separated_list(COMMA, expression) RPAREN
    { FunctionCallStmt (id, args) }
  | FUNC_CALL id=IDENTIFIER
    { FunctionCallStmt (id, []) }
  ;

func_call_with_assign:
  | FUNC_CALL_ASSIGN var=IDENTIFIER FUNC_CALL func=IDENTIFIER LPAREN args=separated_list(COMMA, expression) RPAREN
    { FunctionCallWithAssign (var, func, args) }
  | FUNC_CALL_ASSIGN var=IDENTIFIER FUNC_CALL func=IDENTIFIER
    { FunctionCallWithAssign (var, func, []) }
  ;

return_stmt:
  | RETURN e=expression { Return (Some e) }
  | RETURN %prec RETURN_BARE { Return None }
  ;

try_stmt:
  (* Blok catch zamyka DO CHAŁUPY ALE JUŻ - bez tego połykał resztę programu *)
  | TRY try_block=list(statement) CATCH catch_var=IDENTIFIER catch_block=list(statement) END_IF
    { Try (try_block, catch_var, catch_block) }
  ;

throw_stmt:
  | THROW e=expression { Throw e }
  ;

/* ============ FUNCTIONS ============ */

function_decl:
  (* With return, no params *)
  | FUNC_DECL name=IDENTIFIER FUNC_RETURNS body=list(statement) FUNC_END
    { { name; params = []; is_variadic = false; has_return = true; body } }
  (* Variadic with return - use param_list_with_ellipsis helper *)
  | FUNC_DECL name=IDENTIFIER FUNC_RETURNS FUNC_PARAMS p=param_list_with_ellipsis body=list(statement) FUNC_END
    { { name; params = p; is_variadic = true; has_return = true; body } }
  (* Non-variadic with return and params *)
  | FUNC_DECL name=IDENTIFIER FUNC_RETURNS FUNC_PARAMS params=separated_list(COMMA, IDENTIFIER) body=list(statement) FUNC_END
    { { name; params; is_variadic = false; has_return = true; body } }
  (* Without return, no params *)
  | FUNC_DECL name=IDENTIFIER body=list(statement) FUNC_END
    { { name; params = []; is_variadic = false; has_return = false; body } }
  (* Variadic without return *)
  | FUNC_DECL name=IDENTIFIER FUNC_PARAMS p=param_list_with_ellipsis body=list(statement) FUNC_END
    { { name; params = p; is_variadic = true; has_return = false; body } }
  (* Non-variadic without return, with params *)
  | FUNC_DECL name=IDENTIFIER FUNC_PARAMS params=separated_list(COMMA, IDENTIFIER) body=list(statement) FUNC_END
    { { name; params; is_variadic = false; has_return = false; body } }
  ;

(* Helper rule for variadic params: either "..." or "a, b, c, ..." *)
param_list_with_ellipsis:
  | ELLIPSIS { [] }
  | p=IDENTIFIER COMMA rest=param_list_with_ellipsis { p :: rest }
  ;

/* ============ CLASSES ============ */

class_decl:
  | CLASS name=IDENTIFIER EXTENDS parent=IDENTIFIER members=list(class_member) FUNC_END
    {
      let fields = List.filter_map (function
        | `Field (n, e) -> Some (n, e)
        | `Method _ -> None
      ) members in
      let methods = List.filter_map (function
        | `Field _ -> None
        | `Method m -> Some m
      ) members in
      { name; parent_class = Some parent; fields; methods }
    }
  | CLASS name=IDENTIFIER members=list(class_member) FUNC_END
    {
      let fields = List.filter_map (function
        | `Field (n, e) -> Some (n, e)
        | `Method _ -> None
      ) members in
      let methods = List.filter_map (function
        | `Field _ -> None
        | `Method m -> Some m
      ) members in
      { name; parent_class = None; fields; methods }
    }
  ;

class_member:
  | VAR_DECL id=IDENTIFIER VAR_INIT e=expression
    { `Field (id, e) }
  | f=function_decl
    { `Method f }
  ;

/* ============ STRUCTS ============ */

struct_decl:
  | STRUCT name=IDENTIFIER fields=list(struct_field) END_STRUCT
    { { name; fields } }
  ;

struct_field:
  | VAR_DECL id=IDENTIFIER VAR_INIT e=expression
    { (id, e) }
  ;

/* ============ UNIONS ============ */

union_decl:
  | UNION name=IDENTIFIER fields=list(union_field) END_UNION
    { { name; fields } }
  ;

union_field:
  | VAR_DECL id=IDENTIFIER VAR_INIT e=expression
    { (id, e) }
  ;

/* ============ ENUMS ============ */

enum_decl:
  | ENUM name=IDENTIFIER values=list(enum_value) END_ENUM
    { { name; values } }
  ;

enum_value:
  | id=IDENTIFIER
    { (id, None) }
  | id=IDENTIFIER VAR_INIT n=INTEGER
    { (id, Some n) }
  ;

/* ============ EXPRESSIONS ============ */

expression:
  | e=logical_expr { e }
  (* Ciało lambdy sięga tak daleko, jak się da - jak fun w OCamlu *)
  | LAMBDA LPAREN ps=separated_list(COMMA, IDENTIFIER) RPAREN body=expression
    { Lambda (ps, [Return (Some body)]) }
  (* Ciało z instrukcjami: jak w deklaracji funkcji, NO DOBRZE ALE CO JA Z TEGO BĘDĘ MIAŁ ... DO WIDZENIA PANU *)
  | LAMBDA LPAREN ps=separated_list(COMMA, IDENTIFIER) RPAREN FUNC_RETURNS body=list(statement) FUNC_END
    { Lambda (ps, body) }
  ;

logical_expr:
  | e1=logical_expr AND e2=not_expr
    { LogicalOp (e1, And, e2) }
  | e1=logical_expr OR e2=not_expr
    { LogicalOp (e1, Or, e2) }
  | e=not_expr { e }
  ;

(* TAK BYĆ NIE BĘDZIE: słabiej niż porównania, mocniej niż AND/OR (jak not w Pythonie) *)
not_expr:
  | NOT e=not_expr { LogicalNot e }
  | e=bitwise_expr { e }
  ;

bitwise_expr:
  | e1=bitwise_expr BIT_AND e2=comparison_expr
    { BitwiseOp (e1, BitAnd, e2) }
  | e1=bitwise_expr BIT_OR e2=comparison_expr
    { BitwiseOp (e1, BitOr, e2) }
  | e1=bitwise_expr BIT_XOR e2=comparison_expr
    { BitwiseOp (e1, BitXor, e2) }
  | e1=bitwise_expr BIT_SHIFT_LEFT e2=comparison_expr
    { BitwiseOp (e1, BitShiftLeft, e2) }
  | e1=bitwise_expr BIT_SHIFT_RIGHT e2=comparison_expr
    { BitwiseOp (e1, BitShiftRight, e2) }
  | e=comparison_expr { e }
  ;

comparison_expr:
  | e1=comparison_expr EQUAL e2=arith_expr
    { ComparisonOp (e1, Equal, e2) }
  | e1=comparison_expr NOT_EQUAL e2=arith_expr
    { ComparisonOp (e1, NotEqual, e2) }
  | e1=comparison_expr GREATER e2=arith_expr
    { ComparisonOp (e1, Greater, e2) }
  | e1=comparison_expr LESS e2=arith_expr
    { ComparisonOp (e1, Less, e2) }
  | e1=comparison_expr GREATER_EQUAL e2=arith_expr
    { ComparisonOp (e1, GreaterEqual, e2) }
  | e=arith_expr { e }
  ;

arith_expr:
  | e1=arith_expr PLUS e2=term
    { BinaryOp (e1, Plus, e2) }
  | e1=arith_expr MINUS e2=term
    { BinaryOp (e1, Minus, e2) }
  | e1=arith_expr POINTER_STEP_FORWARD e2=term
    { PointerArithmetic (e1, Plus, e2) }
  | e1=arith_expr POINTER_STEP_BACK e2=term
    { PointerArithmetic (e1, Minus, e2) }
  | e=term { e }
  ;

term:
  | e1=term MULTIPLY e2=factor
    { BinaryOp (e1, Multiply, e2) }
  | e1=term DIVIDE e2=factor
    { BinaryOp (e1, Divide, e2) }
  | e1=term MODULO e2=factor
    { BinaryOp (e1, Modulo, e2) }
  | e=factor { e }
  ;

factor:
  | n=INTEGER { IntLiteral n }
  | f=FLOAT { FloatLiteral f }
  | s=STRING { StringLiteral s }
  | TRUE { BoolLiteral true }
  | FALSE { BoolLiteral false }
  | NULL { NullLiteral }
  | id=IDENTIFIER { Identifier id }
  | ARRAY_INDEX arr=array_access_expr
    { arr }
  | FUNC_CALL id=IDENTIFIER LPAREN args=separated_list(COMMA, expression) RPAREN
    { FunctionCall (id, args) }
  | FUNC_CALL id=IDENTIFIER
    { FunctionCall (id, []) }
  | NEW class_name=IDENTIFIER LPAREN args=separated_list(COMMA, expression) RPAREN
    { NewObject (class_name, args) }
  | NEW class_name=IDENTIFIER
    { NewObject (class_name, []) }
  | NEW_STRUCT struct_name=IDENTIFIER
    { NewStruct struct_name }
  | NEW_UNION union_name=IDENTIFIER
    { NewUnion union_name }
  | POINTER_REF e=factor
    { Reference e }
  | POINTER_DEREF e=factor
    { Dereference e }
  | POINTER_ADDR id=IDENTIFIER
    { AddressOf id }
  | BIT_NOT e=factor
    { BitwiseNot e }
  | TO_FIXED e=factor
    { ToFixed e }
  | FROM_FIXED e=factor
    { FromFixed e }
  | LPAREN e=expression RPAREN
    { Parenthesized e }
  | LBRACKET es=separated_list(COMMA, expression) RBRACKET
    { ArrayLiteral es }
  ;

%%
