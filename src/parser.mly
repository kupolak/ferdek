%{
open Ast
%}

/* Token declarations */
%token PROGRAM_START PROGRAM_END
%token VAR_DECL VAR_INIT
%token PRINT READ
%token ASSIGN_START ASSIGN_OP ASSIGN_END
%token IF ELSE END_IF
%token WHILE END_WHILE
%token FUNC_DECL FUNC_RETURNS FUNC_PARAMS FUNC_END
%token FUNC_CALL FUNC_CALL_ASSIGN RETURN
%token PLUS MINUS MULTIPLY DIVIDE MODULO
%token EQUAL NOT_EQUAL GREATER LESS
%token AND OR
%token TRUE FALSE
%token LPAREN RPAREN COMMA
%token IMPORT
%token ARRAY_DECL
%token ARRAY_INDEX
%token TRY
%token CATCH
%token THROW
%token NULL
%token BREAK
%token CONTINUE
%token CLASS
%token NEW
%token LBRACKET RBRACKET
%token <string> IDENTIFIER
%token <int> INTEGER
%token <string> STRING
%token EOF

/* Precedence and associativity */
%left OR
%left AND
%left EQUAL NOT_EQUAL
%left LESS GREATER
%left PLUS MINUS
%left MULTIPLY DIVIDE MODULO

/* Type declarations */
%type <Ast.expr> expression logical_expr comparison_expr arith_expr term factor
%type <Ast.stmt> statement var_decl array_decl print_stmt read_stmt assign_stmt
%type <Ast.stmt> if_stmt while_stmt func_call_stmt func_call_with_assign
%type <Ast.stmt> return_stmt try_stmt throw_stmt
%type <Ast.function_decl> function_decl
%type <Ast.class_decl> class_decl
%type <Ast.import_stmt> import_stmt
%type <Ast.top_level_decl> top_level_decl

/* Start symbol */
%start <Ast.program> program

%%

/* ============ PROGRAM ============ */

program:
  | PROGRAM_START decls=list(top_level_decl) PROGRAM_END EOF
    { { declarations = decls } }
  ;

top_level_decl:
  | i=import_stmt { Import i }
  | s=statement { Statement s }
  | f=function_decl { FunctionDecl f }
  | c=class_decl { ClassDecl c }
  ;

/* ============ IMPORTS ============ */

import_stmt:
  | IMPORT id=IDENTIFIER { id }
  ;

/* ============ STATEMENTS ============ */

statement:
  | v=var_decl { v }
  | a=array_decl { a }
  | p=print_stmt { p }
  | r=read_stmt { r }
  | a=assign_stmt { a }
  | i=if_stmt { i }
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
  ;

read_stmt:
  | READ id=IDENTIFIER { Read id }
  ;

assign_stmt:
  | ASSIGN_START id=IDENTIFIER ASSIGN_OP e=expression ASSIGN_END
    { Assign (id, e) }
  ;

if_stmt:
  | IF cond=expression then_block=list(statement) END_IF
    { If (cond, then_block, None) }
  | IF cond=expression then_block=list(statement) ELSE else_block=list(statement) END_IF
    { If (cond, then_block, Some else_block) }
  ;

while_stmt:
  | WHILE cond=expression body=list(statement) END_WHILE
    { While (cond, body) }
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
  | RETURN { Return None }
  ;

try_stmt:
  | TRY try_block=list(statement) CATCH catch_var=IDENTIFIER catch_block=list(statement)
    { Try (try_block, catch_var, catch_block) }
  ;

throw_stmt:
  | THROW e=expression { Throw e }
  ;

/* ============ FUNCTIONS ============ */

function_decl:
  | FUNC_DECL name=IDENTIFIER FUNC_RETURNS FUNC_PARAMS params=separated_list(COMMA, IDENTIFIER) body=list(statement) FUNC_END
    { { name; params; has_return = true; body } }
  | FUNC_DECL name=IDENTIFIER FUNC_RETURNS body=list(statement) FUNC_END
    { { name; params = []; has_return = true; body } }
  | FUNC_DECL name=IDENTIFIER FUNC_PARAMS params=separated_list(COMMA, IDENTIFIER) body=list(statement) FUNC_END
    { { name; params; has_return = false; body } }
  | FUNC_DECL name=IDENTIFIER body=list(statement) FUNC_END
    { { name; params = []; has_return = false; body } }
  ;

/* ============ CLASSES ============ */

class_decl:
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
      { name; fields; methods }
    }
  ;

class_member:
  | VAR_DECL id=IDENTIFIER VAR_INIT e=expression
    { `Field (id, e) }
  | f=function_decl
    { `Method f }
  ;

/* ============ EXPRESSIONS ============ */

expression:
  | e=logical_expr { e }
  ;

logical_expr:
  | e1=logical_expr AND e2=comparison_expr
    { LogicalOp (e1, And, e2) }
  | e1=logical_expr OR e2=comparison_expr
    { LogicalOp (e1, Or, e2) }
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
  | e=arith_expr { e }
  ;

arith_expr:
  | e1=arith_expr PLUS e2=term
    { BinaryOp (e1, Plus, e2) }
  | e1=arith_expr MINUS e2=term
    { BinaryOp (e1, Minus, e2) }
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
  | s=STRING { StringLiteral s }
  | TRUE { BoolLiteral true }
  | FALSE { BoolLiteral false }
  | NULL { NullLiteral }
  | id=IDENTIFIER { Identifier id }
  | ARRAY_INDEX id=IDENTIFIER LBRACKET idx=expression RBRACKET
    { ArrayAccess (id, idx) }
  | FUNC_CALL id=IDENTIFIER LPAREN args=separated_list(COMMA, expression) RPAREN
    { FunctionCall (id, args) }
  | FUNC_CALL id=IDENTIFIER
    { FunctionCall (id, []) }
  | NEW class_name=IDENTIFIER LPAREN args=separated_list(COMMA, expression) RPAREN
    { NewObject (class_name, args) }
  | NEW class_name=IDENTIFIER
    { NewObject (class_name, []) }
  | LPAREN e=expression RPAREN
    { Parenthesized e }
  ;

%%
