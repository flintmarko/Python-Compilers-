%{

    #include <cstdio> 
    #include <cstring>
    #include <iostream>
    #include <vector>
    #include <stdio.h>
    #include <bits/stdc++.h>
    #include <string> 
    #include <unistd.h>
    #include "../include/asm.hpp"  
    
    #define YYDEBUG 1

    using namespace std;

    extern "C" int yylex();
    extern "C" int yylineno;

    
    void yyerror(const char* s)  {
        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
        cerr<<"Error at line number: "<<yylineno<<endl;
        cerr<<"Error: "<<s<<endl;
        cerr<<"************************************************************************"<<endl;
    };

    // Lexical global vars
    extern stack<int> INDENT_stack;
    extern stack<int> IMPLICIT_line;
    
    // AST/Parse tree
    void add_child(node *parent, node *child);
    node *start_node;
    int node_number = 0;
    
    // Symbol Table
    symbol_table_generic *symbol_table_root;              // Root of the symbol table
    stack<symbol_table_generic *> current_symbol_table;   // Stack of symbol tables
    map<string, symbol_table_generic *> class_table;      // Map of class tables
    map<string, int> list_map;
    symbol_table_entry *sym_table_lookup(vector<string> &compound_name, node * temp);
    int get_offset(vector<string> &compound_name, node *temp);
    bool flow_stmt_check = false; // to check continue break etc is falling inside while and for loops
    int nested_loop_cnt = 0; // to check continue break etc is falling inside <nested> while and for loops

    // TAC
    void get_temp_of_atom_expr(node *atom_expr, node* parent);
    string get_mangled_name(symbol_table_entry *entry);
    void append_tac(node *parent, node *child);
    string constructor_call = "";
    
    string entrytype[] = {
        "ARRAY",
        "CLASS", 
        "VARIABLE", 
        "FUNCTION", 
        "OBJECT", 
        "LITERAL",
        "DEFAULT"
    };
    string typedata[] = {
        "INT",
        "FLOAT",
        "BOOL",
        "NONE",
        "STRING",
        "CLASS_TYPE",
        "NOTYPE"
    };

    // asm
    vector<int> goto_targets;
    
    //Debugging
    extern int print_debug;
    extern int print_debug2;
    int debug = 0;
    int debug_symbol_table = 1;
    
    
%}

// Make sure that generated parser.tab.h also has relevant includes
// Otherwise we might get errors when using yylval
%code requires 
{ 
    #include <bits/stdc++.h> 
    #include <string>

    using namespace std;
}

// Error handling
%define parse.error detailed
%define parse.lac full

%union{
    char* strval;           // Text for terminals
    struct node* treenode;  // AST node
}
  
// Token declarations for terminals
%token<strval> DEDENT INDENT 
%token<strval> NAME LITERAL_string LITERAL_integer LITERAL_floatingpoint LITERAL_imag
%token<strval> KEYWORD_False                    "False"
%token<strval> KEYWORD_else                     "else" 
%token<strval> KEYWORD_None                     "None" 
%token<strval> KEYWORD_break                    "break" 
%token<strval> KEYWORD_in                       "in" 
%token<strval> KEYWORD_True                     "True" 
%token<strval> KEYWORD_class                    "class" 
%token<strval> KEYWORD_is                       "is" 
%token<strval> KEYWORD_return                   "return" 
%token<strval> KEYWORD_and                      "and" 
%token<strval> KEYWORD_continue                 "continue" 
%token<strval> KEYWORD_for                      "for"
%token<strval> KEYWORD_def                      "def" 
%token<strval> KEYWORD_while                    "while" 
%token<strval> KEYWORD_not                      "not" 
%token<strval> KEYWORD_elif                     "elif"
%token<strval> KEYWORD_if                       "if" 
%token<strval> KEYWORD_or                       "or"
%token<strval> KEYWORD_int                      "int"
%token<strval> KEYWORD_float                    "float" 
%token<strval> KEYWORD_str                      "str"
%token<strval> KEYWORD_bool                     "bool"
%token<strval> KEYWORD_complex                  "complex"
%token<strval> KEYWORD_List                     "list"
%token<strval> KEYWORD_global                   "global"
%token<strval> OPERATOR_add                     "+" 
%token<strval> OPERATOR_subtract                "-"
%token<strval> OPERATOR_multiply                "*" 
%token<strval> OPERATOR_power                   "**"
%token<strval> OPERATOR_divide                  "/" 
%token<strval> OPERATOR_floor_divide             "//" 
%token<strval> OPERATOR_modulo                  "%" 
%token<strval> OPERATOR_left_shift              "<<" 
%token<strval> OPERATOR_right_shift             ">>" 
%token<strval> OPERATOR_bitwise_and             "&"
%token<strval> OPERATOR_bitwise_or              "|" 
%token<strval> OPERATOR_bitwise_xor             "^" 
%token<strval> OPERATOR_bitwise_not             "~" 
%token<strval> OPERATOR_less_than               "<" 
%token<strval> OPERATOR_greater_than            ">"
%token<strval> OPERATOR_less_than_or_equal      "<=" 
%token<strval> OPERATOR_greater_than_or_equal   ">=" 
%token<strval> OPERATOR_equal                   "=="
%token<strval> OPERATOR_not_equal               "!="
%token<strval> DELIMITER_open_parenthesis       "(" 
%token<strval> DELIMITER_close_parenthesis      ")" 
%token<strval> DELIMITER_open_square_bracket    "[" 
%token<strval> DELIMITER_close_square_bracket   "]" 
%token<strval> DELIMITER_comma                  "," 
%token<strval> DELIMITER_colon                  ":" 
%token<strval> DELIMITER_dot                    "." 
%token<strval> DELIMITER_semicolon              ";" 
%token<strval> DELIMITER_equal                  "=" 
%token<strval> DELIMITER_arrow                  "->" 
%token<strval> DELIMITER_plus_equal             "+=" 
%token<strval> DELIMITER_minus_equal            "-=" 
%token<strval> DELIMITER_multiply_equal         "*=" 
%token<strval> DELIMITER_divide_equal           "/=" 
%token<strval> DELIMITER_floor_divide_equal     "//="
%token<strval> DELIMITER_modulo_equal           "%=" 
%token<strval> DELIMITER_bitwise_and_equal      "&="
%token<strval> DELIMITER_bitwise_or_equal       "|="
%token<strval> DELIMITER_bitwise_xor_equal      "^="
%token<strval> DELIMITER_right_shift_equal      ">>="
%token<strval> DELIMITER_left_shift_equal       "<<="
%token<strval> DELIMITER_power_equal            "**="
%token<strval> NEWLINE 

// Token declarations for non-terminals
%type<treenode> power atom_expr atom trailer testlist classdef global_stmt string_plus

%type<treenode> test file_input funcdef func_decl parameters typedargslist tfpdef stmt simple_stmt small_stmt expr_stmt   augassign flow_stmt compound_stmt if_stmt elif_clause_list_opt

%type<treenode> while_stmt while_decl for_decl suite for_stmt stmt_STAR and_test not_test comparison  expr factor term arith_expr shift_expr and_expr xor_expr datatype

// Precedence declarations to deal with parsing conflicts
%precedence NAME LITERAL_string LITERAL_integer LITERAL_floatingpoint LITERAL_imag
%precedence "False" "else" "None" "break" "in" "True" "class" "is" "return" "and" "continue" "for" "def" "while"  "not" "elif" "if" "or" "global"
%precedence "+" "-" "*" "**" "/" "//" "%" "<<" ">>" "&" "|" "^" "~" "<" ">" "<="  ">=" "==" "!="
%precedence "(" ")" "[" "]" "," ":" "." ";" "=" "->" "+=" "-=" "*=" "/=" "//=" "%=" "&=" "|=" "^=" ">>=" "<<=" "**="
%precedence NEWLINE 

%start file_input

%%

file_input:  stmt_STAR  {                              
                            $$ = new node("file_input", false, yylineno, ++node_number);
                            add_child($$, $1);
                            start_node = $$;
                            
                            quadrup *q = new quadrup();
                            q->gen_quad_variable_decl("\"__main__\"", "__name__");
                            $$->tac_codes.push_back(q);
                            $$->tac_str += q->code;
                            
                            append_tac($$, $1);
                        }
;

func_decl:  "def" NAME 
            {   
                //node generation
                $$ = new node("function_defition", false, yylineno, ++node_number);
                node * temp_node = new node("def", true, $1, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                node * temp_node2 = new node("NAME", true, $2, 0, yylineno, ++node_number);
                add_child($$, temp_node2);

          
               //TAC
                symbol_table_generic* sym_temp = new symbol_table_generic($2, "F" , yylineno );  // Generate a symbol 
                symbol_table_generic* parent = current_symbol_table.top();    // parent of function table
                sym_temp->parent_table = parent;   // parent of function table
                symbol_table_entry *temp_entry;
                string temp=$2;
                if(parent->category == "C" && temp == "__init__")             // Check for constructor
                {  
                    if(debug_symbol_table) cout<<"__init__ : Matched __init__ for class :"<<parent->name<<" AT LINE NUMBER "<<$$->lineno<<endl;
                    sym_temp->name = parent->name + ":__init__";
                    temp_entry = new symbol_table_entry(parent->name, FUNCTION, parent, sym_temp, yylineno);
                    temp_entry->is_init = true;
                    if(debug_symbol_table)cout<<"IS INIT OF ENTRY SET TO TRUE OF "<<temp_entry->name<<"PARENT IS "<<parent->name<<endl;


                    //add constructor ki symbol table entry in root symbol table 
                    if(current_symbol_table.top() != symbol_table_root) { 
                        symbol_table_entry * temp_entry2 = new symbol_table_entry(parent->name, FUNCTION, symbol_table_root, sym_temp, yylineno);
                        symbol_table_root->add_entry_constructor(temp_entry2);
                        temp_entry2->is_init = true;
                        
                        //add_entry_constructor so that it does not clashes with class name
                        if(debug_symbol_table)cout<<"ADD_ENTRY : (2) adding entry : "<<temp_entry->name<<" IN symbol table : "<<symbol_table_root->name<<endl;
                    }


                }      
                else 
                    {temp_entry = new symbol_table_entry($2, FUNCTION, parent, sym_temp, yylineno);}
                
                parent->add_entry(temp_entry);   //entry added of function in current symbol table

                if(debug_symbol_table)cout<<"ADD_ENTRY : (1) adding entry : "<<temp_entry->name<<" IN symbol table : "<<parent->name<<endl;
                
                current_symbol_table.push(sym_temp); 
                
                if(debug_symbol_table)cout<<"STACK : TOP OF CURRENT SYMBOL TABLE STACK WAS : "<<parent->name<<" NOW PUSHED : "<<sym_temp->name<<endl;

                // Quadruples
                quadrup *q = new quadrup();
                q->gen_func_decl(get_mangled_name(temp_entry));
                $$->tac_codes.push_back(q);
                $$->tac_str += q->code;

            } 
;

funcdef:
            func_decl parameters "->" datatype ":" 
            { 
                current_symbol_table.top()->return_type = $4->type_data;
                if(debug_symbol_table)cout<<"RETURN TYPE OF FUNCTION IS : "<<typedata[$4->type_data]<<" NAME OF SYMBOL TABLE IS "<<current_symbol_table.top()->name<<endl;
                // cerr<<"RETURN TYPE OF FUNCTION IS : "<<typedata[$4->type_data]<<" NAME OF SYMBOL TABLE IS "<<current_symbol_table.top()->name<<endl;


            } 
            suite    
            {  
                $$ = new node("function_defition", false, yylineno, ++node_number);
                add_child($$, $1);
                add_child($$, $2);
                node * temp_node = new node("DELIMITER_arrow", true, "-&gt;", 0, yylineno, ++node_number);
                add_child($$, temp_node);
                add_child($$, $4);
                temp_node = new node("DELIMITER_colon", true, $5, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                add_child($$, $7);   
                
                current_symbol_table.top()->scope_end_lineno = yylineno;

                append_tac($$, $1);
                append_tac($$, $2);
                append_tac($$, $4);


                for(auto s : $2->atom_name) {
                    quadrup *q = new quadrup();
                    q->gen_func_pop_param(s);
                    $$->tac_codes.push_back(q);
                    $$->tac_str += q->code;
                }

                current_symbol_table.pop(); //current suite ended 

                if(debug_symbol_table) cout<<"STACK (1) POPPED : "<<endl;
                  
                append_tac($$, $7); 
                

                // quadrup *q = new quadrup();
                // q->gen_quad_return("");
                // $$->tac_codes.push_back(q);
                // $$->tac_str += q->code;


                quadrup * q = new quadrup();
                q->gen_quad_end_func();
                $$->tac_codes.push_back(q);
                $$->tac_str += q->code;
            }
|           func_decl parameters ":"
            { 
                current_symbol_table.top()->return_type = NONE;   
            } 
            suite              
            {
                $$ = new node("function_defition", false, yylineno, ++node_number);
                add_child($$, $1);
                add_child($$, $2);
                node *temp_node = new node("DELIMITER_colon", true, $3, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                add_child($$, $5);

                current_symbol_table.top()->scope_end_lineno = yylineno;
            
                if(debug_symbol_table) cout<<"STACK (2) POPPED : "<<endl;

                    append_tac($$, $1);
                    append_tac($$, $2);

                    for(auto s : $2->atom_name) {
                        quadrup *q = new quadrup();
                        q->gen_func_pop_param(s);
                        $$->tac_codes.push_back(q);
                        $$->tac_str += q->code;
                    }

                    current_symbol_table.pop();
                    if(debug_symbol_table) cout<<"STACK (3) POPPED : "<<endl;

                    append_tac($$, $5);

                //  quadrup *q = new quadrup();
                // q->gen_quad_return("");
                // $$->tac_codes.push_back(q);
                // $$->tac_str += q->code;

                     quadrup *q = new quadrup();
                    q->gen_quad_end_func();
                    $$->tac_codes.push_back(q);
                    $$->tac_str += q->code;
            }

; 


parameters: 
"(" typedargslist ")"                       {
                                                $$ = new node("parameters", false, yylineno, ++node_number);
                                                node *temp_node = new node("DELIMITER_open_parenthesis", true, $1, 0, yylineno);
                                                add_child($$, temp_node);
                                                add_child($$, $2);
                                                temp_node = new node("DELIMITER_close_parenthesis", true, $3, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);

                                                append_tac($$, $2);
                                                $$->atom_name = $2->atom_name;
                                            }
| "(" ")"                                   {
                                                $$ = new node("parameters", false, yylineno, ++node_number);
                                                node *temp_node = new node("DELIMITER_open_parenthesis", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                temp_node = new node("DELIMITER_close_parenthesis", true, $2, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);

                                                
                                            }
;

typedargslist:  tfpdef                      {
                                                $$ = new node("typedargslist", false, yylineno, ++node_number);
                                                add_child($$, $1);  
                                                
                                                append_tac($$, $1);
                                                
                                                $$->atom_name.push_back($1->temp_3ac);
}
| typedargslist "," tfpdef                  {
                                                $$ = new node("typedargslist", false, yylineno, ++node_number);
                                                add_child($$, $1);
                                                node *temp_node = new node("DELIMITER_comma", true, $2, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                add_child($$, $3);
                                                
                                                append_tac($$, $1);
                                                append_tac($$, $3);
                                                
                                                $$->atom_name = $1->atom_name;
                                                $$->atom_name.push_back($3->temp_3ac);
                                                
                                            }
;
tfpdef: NAME                                {   //only for self as self will not have type

                                                $$ = new node("tfpdef", false, yylineno, ++node_number);                                                
                                                node *temp_node = new node("NAME", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);



                                                symbol_table_generic* sym_temp = current_symbol_table.top();
                                                symbol_table_entry* temp_entry = new symbol_table_entry($1, NONE, sym_temp, yylineno);
                                                sym_temp->add_entry(temp_entry);
                                                if(debug_symbol_table)cout<<"ADD_ENTRY : (3) adding entry :"<<temp_entry->name<<" IN symbol table : "<<sym_temp->name<<endl;
                                                if(temp_entry->name!="self") sym_temp->add_params(temp_entry);
                                                $$->entry = temp_entry;

                                                $$->temp_3ac = $1;

                                            }
| NAME ":" datatype                         {
                                                $$ = new node("tfpdef", false, yylineno, ++node_number);
                                                node *temp_node = new node("NAME", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                temp_node = new node("DELIMITER_colon", true, $2, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                add_child($$, $3);
                                                
                                                symbol_table_generic* sym_temp = current_symbol_table.top();
                                                symbol_table_entry *temp_entry = new symbol_table_entry($1, $3 ->type_data, sym_temp, yylineno);
                                                sym_temp->add_entry(temp_entry);
                                                if(debug_symbol_table)cout<<"ADD_ENTRY :  (4) adding entry :"<<temp_entry->name<<" IN symbol table : "<<sym_temp->name<<endl;

                                                if(temp_entry->name!= "self")sym_temp->add_params(temp_entry);
                                                
                                                temp_entry->type_entry = $3->type_entry;

                                                $$->entry = temp_entry;
                                                
                                                append_tac($$, $3);
                                                $$->temp_3ac = $1;
                                                if($3->type_entry == ARRAY || $3->type_entry == OBJECT){
                                                    $$->entry->base_ptr_3ac = $1;
                                                }
                                            }
;

datatype:
"None"                                      {
                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_None", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                
                                                $$->type_data = NONE;
                                                $$->type_entry = VARIABLE;
                                            }
| "int"                                      {
                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_int", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);

                                                $$->type_data = INT;
                                                $$->type_entry = VARIABLE;
                                            }
| "float"                                   {
                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_float", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);

                                                $$->type_data = FLOAT;
                                                $$->type_entry = VARIABLE;
                                            }
| "str"                                     {
                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_str", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);

                                                $$->type_data = STRING;
                                                $$->type_entry = VARIABLE;
                                            }
| "bool"                                    {
                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_bool", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);

                                                $$->type_data = BOOL;
                                                $$->type_entry = VARIABLE;
                                            }
| NAME                                      {


                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("NAME", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                
                                                $$->lexeme = $1;
                                                $$->type_data = CLASS_TYPE;
                                                $$->type_entry = OBJECT;


                                            }
| "list" "[" "int" "]"                       {
                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_List", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                node *temp_node2 = new node("DELIMITER_open_square_bracket", true, $2, 0, yylineno, ++node_number);
                                                add_child($$, temp_node2);
                                                node *temp_node3 = new node("KEYWORD_int", true, $3, 0, yylineno, ++node_number);
                                                add_child($$, temp_node3);
                                                node *temp_node4 = new node("DELIMITER_close_square_bracket", true, $4, 0, yylineno, ++node_number);
                                                add_child($$, temp_node4);

                                                $$->type_entry = ARRAY;
                                                $$->type_data = INT;
                                            }
| "list" "[" "float" "]"                     {  
                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_List", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                node *temp_node2 = new node("DELIMITER_open_square_bracket", true, $2, 0, yylineno, ++node_number);
                                                add_child($$, temp_node2);
                                                node *temp_node3 = new node("KEYWORD_float", true, $3, 0, yylineno, ++node_number);
                                                add_child($$, temp_node3);
                                                node *temp_node4 = new node("DELIMITER_close_square_bracket", true, $4, 0, yylineno, ++node_number);
                                                add_child($$, temp_node4);

                                                $$->type_entry = ARRAY;
                                                $$->type_data = FLOAT;


                                            }
| "list" "[" "str" "]"                       {  
                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_List", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                node *temp_node2 = new node("DELIMITER_open_square_bracket", true, $2, 0, yylineno, ++node_number);
                                                add_child($$, temp_node2);
                                                node *temp_node3 = new node("KEYWORD_str", true, $3, 0, yylineno, ++node_number);
                                                add_child($$, temp_node3);
                                                node *temp_node4 = new node("DELIMITER_close_square_bracket", true, $4, 0, yylineno, ++node_number);
                                                add_child($$, temp_node4);

                                                $$->type_entry = ARRAY;
                                                $$->type_data = STRING ;

                                            }
| "list" "[" "bool" "]"                      { 
                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_List", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                node *temp_node2 = new node("DELIMITER_open_square_bracket", true, $2, 0, yylineno, ++node_number);
                                                add_child($$, temp_node2);
                                                node *temp_node3 = new node("KEYWORD_bool", true, $3, 0, yylineno, ++node_number);
                                                add_child($$, temp_node3);
                                                node *temp_node4 = new node("DELIMITER_close_square_bracket", true, $4, 0, yylineno, ++node_number);
                                                add_child($$, temp_node4);

                                                $$->type_entry = ARRAY;
                                                $$->type_data = BOOL ;
                                            }
| "list" "[" NAME "]"                       {   
                                                $$ = new node("datatype", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_List", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                node *temp_node2 = new node("DELIMITER_open_square_bracket", true, $2, 0, yylineno, ++node_number);
                                                add_child($$, temp_node2);
                                                node *temp_node3 = new node("NAME", true, $3, 0, yylineno, ++node_number);
                                                add_child($$, temp_node3);
                                                node *temp_node4 = new node("DELIMITER_close_square_bracket", true, $4, 0, yylineno, ++node_number);
                                                add_child($$, temp_node4);

                                                $$->type_entry = ARRAY;
                                                $$->type_data = CLASS_TYPE;

                                                if(class_table[$3] == NULL){
                                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                    cerr<<"Error : Invalid class name in list declaration"<<endl;
                                                    cerr<<"************************************************************************"<<endl;
                                                }
                                            }
;

stmt:  simple_stmt                          {
                                                $$ = new node("stmt", false, yylineno, ++node_number);
                                                add_child($$, $1);
                                                append_tac($$, $1);
                                                $$->temp_3ac = $1->temp_3ac;
                                            }
| compound_stmt                             {
                                                $$ = new node("stmt", false, yylineno, ++node_number);
                                                add_child($$, $1);      
                                                append_tac($$, $1); 
                                                $$->temp_3ac = $1->temp_3ac;                                     
                                            }                       
;

simple_stmt:
small_stmt ";" NEWLINE                          {
                                                    $$ = new node("simple_stmt", false, yylineno, ++node_number);
                                                    add_child($$, $1);
                                                    node *temp_node = new node("DELIMITER_semicolon", true, $2, 0, yylineno, ++node_number);
                                                    add_child($$, temp_node);
                                                    append_tac($$, $1);
                                                }   
| small_stmt NEWLINE                            { 
                                                    $$ = new node("simple_stmt", false, yylineno, ++node_number);
                                                    add_child($$, $1);
                                                    append_tac($$, $1);
                                                }      
| small_stmt ";" simple_stmt                    {
                                                    $$ = new node("simple_stmt", false, yylineno, ++node_number);
                                                    add_child($$, $1);
                                                    node *temp_node = new node("DELIMITER_semicolon", true, $2, 0, yylineno, ++node_number);
                                                    add_child($$, temp_node);
                                                    add_child($$, $3);
                                                    append_tac($$, $1);
                                                    append_tac($$, $3);
                                                }
;

small_stmt: 
    expr_stmt                   {
                                    $$ = new node("small_stmt", false, yylineno, ++node_number);
                                    add_child($$, $1);
                                    append_tac($$, $1);
                                    $$->temp_3ac = $1->temp_3ac;
                                }
|   flow_stmt                   {
                                    $$ = new node("small_stmt", false, yylineno, ++node_number);
                                    add_child($$, $1);
                                    append_tac($$, $1);
                                    $$->temp_3ac = $1->temp_3ac;
                                }
|   global_stmt                 {
                                    $$ = new node("small_stmt", false, yylineno, ++node_number);
                                    add_child($$, $1);
                                    append_tac($$, $1);
                                    $$->temp_3ac = $1->temp_3ac;
                                }
;

global_stmt:   
"global" NAME                                               {
                                                                $$ = new node("global_stmt", false, yylineno, ++node_number);
                                                                node *temp_node = new node("KEYWORD_global", true, $1, 0, yylineno, ++node_number);
                                                                add_child($$, temp_node);
                                                                node *temp_node2 = new node("NAME", true, $2, 0, yylineno, ++node_number);
                                                                add_child($$, temp_node2);

                                                                
                                                                vector<string> comp_name;
                                                                string name = $2;
                                                                comp_name.push_back(name);
                                                                symbol_table_entry * temp_entry = sym_table_lookup(comp_name, $$);
                                                                //checks for the case where global a and a is not declared
                                                                if(temp_entry==NULL){
                                                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                    cerr<<"Error : Global used but variable not already declared"<<endl;
                                                                    cerr<<"************************************************************************"<<endl;
                                                                    exit(1);
                                                                }   
                                                                //checks for the case where global a and a is declared in the same scope 
                                                                else current_symbol_table.top()->add_entry(temp_entry);


                                                            } 
| global_stmt "," NAME                                      {
                                                                $$ = new node("global_stmt", false, yylineno, ++node_number);
                                                                add_child($$, $1);
                                                                node *temp_node = new node("DELIMITER_comma", true, $2, 0, yylineno, ++node_number);
                                                                add_child($$, temp_node);
                                                                node *temp_node2 = new node("NAME", true, $3, 0, yylineno, ++node_number);
                                                                add_child($$, temp_node2);

                                                                append_tac($$, $1);

                                                                vector<string> comp_name;
                                                                string name = $3;
                                                                comp_name.push_back(name);
                                                                symbol_table_entry * temp_entry = sym_table_lookup(comp_name, $$);
                                                                //checks for the case where global a and a is not declared

                                                                if(temp_entry==NULL){
                                                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                    cerr<<"Error : Global used but variable not already declared"<<endl;
                                                                    cerr<<"************************************************************************"<<endl;
                                                                    exit(1);
                                                                }
                                                                //checks for the case where global a and a is declared in the same scope 

                                                                else current_symbol_table.top()->add_entry(temp_entry);

                                                            }
;

expr_stmt: atom_expr ":" datatype                       {
                                                            $$ = new node("expr_stmt", false, yylineno, ++node_number);
                                                            add_child($$, $1);
                                                            node *temp_node = new node("DELIMITER_colon", true, $2, 0, yylineno, ++node_number);
                                                            add_child($$, temp_node);
                                                            add_child($$, $3);

                                                            vector<string>name = $1->atom_name;
                                                            symbol_table_entry *temp_entry = new symbol_table_entry(name[name.size()-1], $3->type_data, current_symbol_table.top(), $1->lineno);
                                                            temp_entry->type_entry = $3->type_entry;
                                                            
                                                            if($3->type_data == CLASS_TYPE)
                                                            {   //object created for a class not declared
                                                                temp_entry->class_name = $3->lexeme;
                                                                //check if class of this name is declared or not 
                                                                if(class_table[$3->lexeme] == NULL){
                                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                cerr<<"ERROR : Class "<<$3->lexeme<<" not declared"<<endl;
                                                                cerr<<"************************************************************************"<<endl;
                                                                exit(1);
                                                                }
                                                            }
                                                             
                                                            if((current_symbol_table.top()->category == "F" && current_symbol_table.top()->parent_table->category == "C" && name[0]=="self")){}
                                                            else { current_symbol_table.top()->add_entry(temp_entry);
                                                            if(debug_symbol_table)cout<<"ADD_ENTRY : (6) adding entry :"<<temp_entry->name<<" IN symbol table : "<<current_symbol_table.top()->name<<endl;}

                                                            

                                                           if((current_symbol_table.top()->category == "C")) {
                                                                
                                                                if($3->type_entry == VARIABLE  ) {      // allocate 8 bytes for this 
                                                                    temp_entry->offset = current_symbol_table.top()->size;
                                                                    current_symbol_table.top()->size += 8;
                                                                } 
                                                                 else if($3->type_entry == OBJECT){
                                                                    temp_entry->offset = current_symbol_table.top()->size;
                                                                    current_symbol_table.top()->size +=  class_table[$3->lexeme]->size;
                                                                }
                                                            }
                                                             else if((current_symbol_table.top()->category == "F" && current_symbol_table.top()->parent_table->category == "C" && name[0]=="self")){
                                                                symbol_table_generic * sym_parent = current_symbol_table.top()->parent_table;
                                                                 if($3->type_entry == VARIABLE) {      // allocate 8 bytes for this 
                                                                        temp_entry->offset = sym_parent->size;
                                                                        sym_parent->size += 8;
                                                                } 
                                                                else if($3->type_entry == OBJECT){
                                                                    temp_entry->offset = sym_parent->size;
                                                                    sym_parent->size +=  class_table[$3->lexeme]->size;
                                                                }
                                                                //init ke andar jitni declarations hain vo class m daaldo 
                                                                if(debug_symbol_table) cout<<"ADDING DECLARATIONS INSIDE INIT TO PARENT CLASS OF NAME "<<sym_parent->name<<endl;
                                                                sym_parent->add_entry(temp_entry);

                                                            }
                                                            $$->entry=temp_entry;

                                                            get_temp_of_atom_expr($1 , $$);
                                                            append_tac($$, $3);
                                                            append_tac($$, $1);
                                                            $$->temp_3ac = $1->temp_3ac;

                                                        }
| atom_expr "=" test                                    {
                                                            $$ = new node("expr_stmt", false, yylineno, ++node_number);
                                                            add_child($$, $1);
                                                            node *temp_node = new node("DELIMITER_equal", true, $2, 0, yylineno, ++node_number);
                                                            add_child($$, temp_node);
                                                            add_child($$, $3);
                                                                           
                                                            if($1->type_entry == CLASS || $1->type_entry == LITERAL || $1->type_entry == FUNCTION){
                                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                cerr<<"Error : Left had side of assignment cannot be a class or a literal or a function and IT IS : "<<entrytype[$1->type_entry]<<endl;
                                                                cerr<<"************************************************************************"<<endl;
                                                                exit(1);
                                                            }
                                                            
                                                            symbol_table_entry* entry = sym_table_lookup($1->atom_name, $1);
                                                            if(entry == NULL) {
                                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                cerr<<"Error: Variable "<<$1->atom_name[$1->atom_name.size()-1]<<" not declared AT line number : "<<$$->lineno<<endl;
                                                                cerr<<"************************************************************************"<<endl;
                                                                exit(1);
                                                            }
                                                            if(debug_symbol_table)cout<<"LOOK_UP: "<<entry->name<< "CLASS OF ENTRY : "<<entry->present_table->name<<endl;
                                                            
                                                            if($1->type_entry == CLASS || $1->type_entry == LITERAL || $1->type_entry == FUNCTION){
                                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                cerr<<"Error : Left had side of assignment cannot be a class or a literal or a function and IT IS : "<<entrytype[$1->type_entry]<<endl;
                                                                cerr<<"************************************************************************"<<endl;
                                                                exit(1);
                                                            }

                                                            if( !($3->type_entry == ARRAY && $3->array_types.size()==0 ) && entry->type_entry != OBJECT && !check_data_type($1->type_data , $3->type_data)){
                                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                cerr<<"ERROR : type checking error in declaration assignment"<<endl;
                                                                cerr<<"************************************************************************"<<endl;
                                                                exit(1);
                                                            }

                                                            

                                                            if(entry->type_entry == OBJECT) { // allocate memory

                                                                //machli append($$ , $1) kahan aayega vro phele ya badme
                                                                append_tac($$, $1);

                                                                // quadrup* q = new quadrup();
                                                                // uint64_t size = class_table[entry->class_name]->size;
                                                                // q->gen_quad_push_param(to_string(size));
                                                                // $$->tac_codes.push_back(q);
                                                                // $$->tac_str += q->code;

                                                                // q = new quadrup();
                                                                // q->gen_quad_call_func("allocmem");
                                                                // $$->tac_codes.push_back(q);
                                                                // $$->tac_str += q->code;

                                                                // q = new quadrup();
                                                                // q->gen_quad_variable_decl("Return_value" ,  $1->temp_3ac);
                                                                // $$->tac_codes.push_back(q);
                                                                // $$->tac_str += q->code;

                                                                quadrup* q;
                                                                entry->base_ptr_3ac = $1->temp_3ac;
                                                                if(debug_symbol_table)cout<<"SETTING BASE PTR "<<$1->temp_3ac<<endl;
                                                                
                                                                if(debug_symbol_table) cout<<"PUSHING SELF ONTO FUNCTION STACK"<<endl;
                                                                if(debug_symbol_table) cout<<"INSIDE ATOM_EXPR == TEST"<<endl;
                                                                if(debug_symbol_table) cout<<"temp_entry is : "<<$3->type_entry<<endl;
                                                                if($3->type_entry == FUNCTION){
                                                                    // if(debug_symbol_table)cout<<" NOW : FUNCTION LOOKUP : "<<endl;
                                                                    // if(debug_symbol_table)cout<<" NOW : FUNCTION LOOKUP : "<<$3->atom_name[0]<<endl;

                                                                    symbol_table_entry* temp_entry2 = current_symbol_table.top()->lookup_func_no_param($3->atom_test->lexeme);
                                                                    if(temp_entry2 == NULL){
                                                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                        cerr<<"Error : Undeclared function "<<endl;
                                                                        cerr<<"************************************************************************"<<endl;
                                                                        exit(1);
                                                                    }
                                                                    else if(temp_entry2 != NULL && temp_entry2->is_init){
                                                                        q = new quadrup();
                                                                        q->gen_func_push_param(entry->base_ptr_3ac);
                                                                        $$->tac_codes.push_back(q);
                                                                        $$->tac_str += q->code;
                                                                        $$->temp_3ac = "t_"+to_string($$->node_number);
                                                                        append_tac($$, $3);
                                                                    } 
                                                                    else{
                                                                        $$->temp_3ac = "t_"+to_string($$->node_number);
                                                                        append_tac($$, $3);
                                                                        q = new quadrup();
                                                                        q->gen_quad_variable_decl($3->temp_3ac, entry->base_ptr_3ac);
                                                                        $$->tac_codes.push_back(q);
                                                                        $$->tac_str += q->code;
                                                                    }
                                                                    
                                                                }
                                                                else{
                                                                    if(debug_symbol_table) cout<<" NOT FUNCTION IN ATOM_EXPR = TEST"<<endl;
                                                                    
                                                                    q = new quadrup();
                                                                    q->gen_quad_variable_decl($3->temp_3ac, entry->base_ptr_3ac);
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;
                                                                    $$->temp_3ac = "t_"+to_string($$->node_number);
                                                                    append_tac($$, $3);
                                                                }
                                                                
                                                                
                                                                

                                                            }
                                                            else if(entry->type_entry == ARRAY && $1->atom_name.size()!=1 && $1->atom_name.back()!="[]" ){
                                                                
                                                                entry->base_ptr_3ac = $1->temp_3ac;
                                                                if(debug_symbol_table)cout<<"SETTING BASE PTR "<<$1->temp_3ac<<endl;
                                                                append_tac($$, $3);
                                                                get_temp_of_atom_expr($1 ,$$);
                                                                append_tac($$, $1);

                                                                // quadrup *q = new quadrup();
                                                                // q->gen_quad_variable_decl($5->temp_3ac, $1->temp_3ac);
                                                                // $$->tac_codes.push_back(q);
                                                                // $$->tac_str += q->code;

                                                                //we have self_array and base pointer of the memory in

                                                                //ap
                                                                int size_of_array = $3->array_types.size();
                                                                for(int i= 0;i<size_of_array;i++){
                                                                    quadrup* q = new quadrup();
                                                                    q->gen_quad_operator($3->temp_3ac , to_string( i * 8), $3->temp_3ac + "_" + to_string(i), "+");
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str+= q->code; 

                                                                    q = new quadrup();
                                                                    q->gen_quad_operator($1->temp_3ac , to_string( i * 8), $1->temp_3ac + "_" + to_string(i), "+");
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str+= q->code; 

                                                                    // q = new quadrup();
                                                                    // string arg1 = "*"+($3->temp_3ac) + "_" + (to_string(i)) ;
                                                                    // string result = "*"+($1->temp_3ac) + "_" + (to_string(i)) ;
                                                                    // q->gen_quad_variable_decl(arg1, result);
                                                                    // $$->tac_codes.push_back(q);
                                                                    // $$->tac_str+= q->code; 

                                                                    q = new quadrup();
                                                                    q->gen_quad_variable_dereference($3->temp_3ac + "_" + to_string(i), $3->temp_3ac + "_" + to_string(i));
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str+= q->code;

                                                                    q = new quadrup();
                                                                    q->gen_quad_variable_dereference_left($3->temp_3ac + "_" + to_string(i), $1->temp_3ac + "_" + to_string(i));
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str+= q->code;


                                                                }
                                                            }
                                                            else{ 
                                                                //machli ye order of appending sahi hai kya?
                                                                if(entry->type_entry==ARRAY)entry->base_ptr_3ac = $1->temp_3ac;

                                                                append_tac($$, $3);
                                                                get_temp_of_atom_expr($1 ,$$);
                                                                
                                                                append_tac($$, $1);

                                                                quadrup *q = new quadrup();
                                                                q->gen_quad_variable_decl($3->temp_3ac, $1->temp_3ac);
                                                                $$->tac_codes.push_back(q);
                                                                $$->tac_str += q->code;
                                                            }
                                                            // get_temp_of_atom_expr($1 , $$);
                                                            // append_tac($$, $1);
                                                            // append_tac($$, $3);
                                                            // quadrup * q = new quadrup();
                                                            // q->gen_quad_variable_decl($3->temp_3ac, $1->temp_3ac);
                                                            // $$->tac_codes.push_back(q);
                                                            // $$->tac_str += q->code;

                                                            if($1->type_entry == ARRAY){
                                                                if(debug_symbol_table) cout<<"INSIDE ARRAY RHS"<<endl;
                                                                if(debug_symbol_table) cout<<"TYPE OF ELEMENTS IN ARRAY ARE :"<<endl;
                                                                for(auto s : $3->array_types){
                                                                    if(debug_symbol_table) cout<<s<<" ";
                                                                    if( !check_data_type($1->type_data , s)){
                                                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                        cerr<<"Error : type checking error in list"<<endl;
                                                                        cerr<<"************************************************************************"<<endl;
                                                                        exit(1);
                                                                    }
                                                                }
                                                                if(debug_symbol_table) cout<<endl;
                                                            }
                                                            
                                                        }
| atom_expr ":" datatype "=" test                       {     
                                                            $$ = new node("expr_stmt", false, yylineno, ++node_number);
                                                            add_child($$, $1);
                                                            node * temp_node = new node("DELIMITER_colon", true, $2, 0, yylineno, ++node_number);
                                                            add_child($$, temp_node);
                                                            add_child($$, $3);
                                                            node *temp_node2 = new node("DELIMITER_equal", true, $4, 0, yylineno, ++node_number);
                                                            add_child($$, temp_node2);
                                                            add_child($$, $5); 


                                                            vector<string> name = $1->atom_name;
                                                            symbol_table_entry *temp_entry = new symbol_table_entry(name[name.size()-1], $3->type_data, current_symbol_table.top(), $1->lineno);
                                                            temp_entry->type_entry = $3->type_entry;
                                                            if(debug_symbol_table)cout<<" expr_stmt : "<<temp_entry->name<<" "<<typedata[temp_entry->type_data]<<" "<<entrytype[temp_entry->type_entry]<<endl;
                                                            if($3->type_data == CLASS_TYPE)
                                                            {   
                                                                temp_entry->class_name = $3->lexeme;
                                                                if(class_table[$3->lexeme] == NULL){
                                                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                    cerr<<"ERROR : Class "<<$3->lexeme<<" not declared "<<endl;
                                                                    cerr<<"************************************************************************"<<endl;
                                                                    exit(1);
                                                                }
                                                            }
                                                            if((current_symbol_table.top()->category == "F" && current_symbol_table.top()->parent_table->category == "C" && name[0]=="self"));
                                                            else {
                                                                current_symbol_table.top()->add_entry(temp_entry);
                                                                if(debug_symbol_table)cout<<"ADD_ENTRY :  (7) adding entry :"<<temp_entry->name<<" IN symbol table : "<<current_symbol_table.top()->name<<endl;
                                                            }
                                                            
                                                            if( !($3->type_entry == ARRAY && $3->array_types.size()==0 ) && $3->type_data != CLASS_TYPE && !check_data_type($3->type_data , $5->type_data)){
                                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                cerr<<"ERROR : type checking error in declaration assignment"<<endl;
                                                                cerr<<"************************************************************************"<<endl;
                                                                exit(1);
                                                            }
                                                            if($3->type_entry == ARRAY && ($5->type_entry==FUNCTION || $5->type_entry == ARRAY) ){
                                                                
                                                                // quadrup *q = new quadrup();
                                                                // q->gen_quad_variable_decl($5->temp_3ac, $1->temp_3ac);
                                                                // $$->tac_codes.push_back(q);
                                                                // $$->tac_str += q->code;
                                                                if($5->type_entry == VARIABLE)list_map[$1->atom_name[0]] = list_map[$5->atom_name[0]];
                                                            }
                                                            else if($3->type_entry == ARRAY){
                                                                if(debug_symbol_table) cout<<"INSIDE LIST DECLARATIONS RHS"<<endl;
                                                                
                                                                if($5->atom_test->type_entry != ARRAY) {
                                                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                    cerr<<"ERROR : Array declared but right hand side is not an array "<<endl;
                                                                    cerr<<"************************************************************************"<<endl;
                                                                    exit(1);                                                               
                                                                }
                                                                temp_entry->array_datatype = $5->array_types;
                                                                temp_entry->array_dims = $5->array_types.size();
                                                                list_map[$1->atom_name[0]] = $5->array_types.size();
                                                                if(debug_symbol_table) cout<<"name of array is "<<$1->atom_name[0]<<" of size "<<$5->array_types.size()<<endl;
                                                                if(debug_symbol_table) cout<<"TYPE OF ELEMENTS IN ARRAY ARE :"<<endl;
                                                                for(auto s : $5->array_types) {
                                                                    if(debug_symbol_table) cout<<s<<" ";
                                                                    if( !check_data_type($3->type_data , s)) {
                                                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                        cerr<<"ERROR : type checking error in list"<<endl;
                                                                        cerr<<"************************************************************************"<<endl;
                                                                        exit(1);
                                                                    }
                                                                }
                                                                if(debug_symbol_table) cout<<endl;
                                                            }

                                                            if((current_symbol_table.top()->category == "C")) {
                                                                if($3->type_entry == VARIABLE) {      // allocate 8 bytes for this 
                                                                    temp_entry->offset = current_symbol_table.top()->size;
                                                                    current_symbol_table.top()->size += 8;
                                                                } else if($3->type_entry == ARRAY) {  // allocate 8 * size of array 
                                                                    temp_entry->offset = current_symbol_table.top()->size;
                                                                    current_symbol_table.top()->size += 8 * $5->array_types.size();
                                                                }
                                                                else if($3->type_entry == OBJECT){
                                                                    temp_entry->offset = current_symbol_table.top()->size;
                                                                    current_symbol_table.top()->size +=  class_table[$3->lexeme]->size;
                                                                }
                                                            }
                                                            else if((current_symbol_table.top()->category == "F" && current_symbol_table.top()->parent_table->category == "C" && name[0]=="self")){
                                                                symbol_table_generic * sym_parent = current_symbol_table.top()->parent_table;
                                                                if($3->type_entry == VARIABLE) {      // allocate 8 bytes for this 
                                                                    temp_entry->offset = sym_parent->size;
                                                                    sym_parent->size += 8;
                                                                    if(debug_symbol_table) cout<<"OFFSET OF "<<temp_entry->name<<" IS "<<temp_entry->offset<<endl;
                                                                } else if($3->type_entry == ARRAY) {  // allocate 8 * size of array 
                                                                    temp_entry->offset = sym_parent->size;
                                                                    sym_parent->size += 8 * $5->array_types.size();
                                                                }
                                                                else if($3->type_entry == OBJECT) {
                                                                    temp_entry->offset = sym_parent->size;
                                                                    sym_parent->size +=  class_table[$3->lexeme]->size;
                                                                    
                                                                }
                                                                if(debug_symbol_table) cout<<"ADDING DECLARATIONS INSIDE INIT TO PARENT CLASS OF NAME "<<current_symbol_table.top()->parent_table->name<<endl;
                                                                if(debug_symbol_table) cout<<"ADDING DECLARATI0NS INSIDE INIT TO PARENT CLASS OF NAME ENTRY NAME "<<temp_entry->name<<endl;
                                                                current_symbol_table.top()->parent_table->add_entry(temp_entry);

                                                            }
                                                            $$->entry = temp_entry;


                                                            if($3->type_entry == OBJECT) { // allocate memory

                                                                //machli append($$ , $1) kahan aayega vro phele ya badme
                                                                append_tac($$, $1);

                                                                quadrup* q = new quadrup();
                                                                uint64_t size = class_table[$3->lexeme]->size;
                                                                q->gen_quad_push_param(to_string(size));
                                                                $$->tac_codes.push_back(q);
                                                                $$->tac_str += q->code;

                                                                q = new quadrup();
                                                                q->gen_quad_call_func("allocmem");
                                                                $$->tac_codes.push_back(q);
                                                                $$->tac_str += q->code;

                                                                q = new quadrup();
                                                                q->gen_func_get_retval($1->temp_3ac);
                                                                $$->tac_codes.push_back(q);
                                                                $$->tac_str += q->code;


                                                                temp_entry->base_ptr_3ac = $1->temp_3ac;
                                                                if(debug_symbol_table)cout<<"SETTING BASE PTR "<<$1->temp_3ac<<endl;
                                                                
                                                                
                                                                if($5->type_entry == FUNCTION  ){
                                                                    symbol_table_entry* temp_entry2 = current_symbol_table.top()->lookup_func_no_param($5->atom_test->lexeme);
                                                                    if(temp_entry2 == NULL){
                                                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                        cerr<<"Error : Undeclared function "<<endl;
                                                                        cerr<<"************************************************************************"<<endl;
                                                                        exit(1);
                                                                    }
                                                                    else if(temp_entry2 != NULL && temp_entry2->is_init){

                                                                        if(debug_symbol_table) cout<<"PUSHING SELF ONTO FUNCTION STACK"<<endl;
                                                                        q = new quadrup();
                                                                        q->gen_func_push_param(temp_entry->base_ptr_3ac);
                                                                        $$->tac_codes.push_back(q);
                                                                        $$->tac_str += q->code;
                                                                        $$->temp_3ac = "t_"+to_string($$->node_number);
                                                                        append_tac($$, $5);

                                                                    }
                                                                    else{
                                                                        $$->temp_3ac = "t_"+to_string($$->node_number);
                                                                        append_tac($$, $5);

                                                                        q = new quadrup();
                                                                        q->gen_quad_variable_decl($5->temp_3ac, temp_entry->base_ptr_3ac);
                                                                        $$->tac_codes.push_back(q);
                                                                        $$->tac_str += q->code;
                                                                    }
                                                                }
                                                                else{
                                                                    q = new quadrup();
                                                                    q->gen_quad_variable_decl($5->temp_3ac, temp_entry->base_ptr_3ac);
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;
                                                                    $$->temp_3ac = "t_"+to_string($$->node_number);
                                                                    append_tac($$, $5);

                                                                }
                                                                


                                                                // get_temp_of_atom_expr($1 ,$$);
                                                                // append_tac($$, $1);
                                                                // q = new quadrup();
                                                                // q->gen_func_get_retval_none();
                                                                // $$->tac_codes.push_back(q);
                                                                // $$->tac_str += q->code;
                                                                // q = new quadrup();
                                                                // q->gen_quad_return("");
                                                                // $$->tac_codes.push_back(q);
                                                                // $$->tac_str += q->code;
                                                            }
                                                            else if($3->type_entry == ARRAY && $1->atom_name.size()!=1){
                                                                
                                                                temp_entry->base_ptr_3ac = $1->temp_3ac;
                                                                if(debug_symbol_table)cout<<"SETTING BASE PTR "<<$1->temp_3ac<<endl;
                                                                append_tac($$, $5);
                                                                get_temp_of_atom_expr($1 ,$$);
                                                                append_tac($$, $1);

                                                                // quadrup *q = new quadrup();
                                                                // q->gen_quad_variable_decl($5->temp_3ac, $1->temp_3ac);
                                                                // $$->tac_codes.push_back(q);
                                                                // $$->tac_str += q->code;

                                                                //we have self_array and base pointer of the memory in

                                                                //ap
                                                                int size_of_array = $5->array_types.size();
                                                                for(int i= -1;i<size_of_array;i++){
                                                                    quadrup* q = new quadrup();
                                                                    q->gen_quad_operator($5->temp_3ac , to_string( i * 8), $5->temp_3ac + "_" + to_string(abs(i)), "+");
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str+= q->code; 

                                                                    q = new quadrup();
                                                                    q->gen_quad_operator($1->temp_3ac , to_string( i * 8), $1->temp_3ac + "_" + to_string(abs(i)), "+");
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str+= q->code; 

                                                                    // q = new quadrup();
                                                                    // string arg1 = "*"+($5->temp_3ac) + "_" + (to_string(i)) ;
                                                                    // string result = "*"+($1->temp_3ac) + "_" + (to_string(i)) ;
                                                                    // q->gen_quad_variable_decl(arg1, result);
                                                                    // $$->tac_codes.push_back(q);
                                                                    // $$->tac_str+= q->code; 

                                                                    q = new quadrup();
                                                                    q->gen_quad_variable_dereference($5->temp_3ac + "_" + to_string(abs(i)), $5->temp_3ac + "_" + to_string(abs(i)));
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str+= q->code;

                                                                    q = new quadrup();
                                                                    q->gen_quad_variable_dereference_left($5->temp_3ac + "_" + to_string(abs(i)), $1->temp_3ac + "_" + to_string(abs(i)));
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str+= q->code;

                                                                }
                                                            }
                                                            else{ 
                                                                //machli ye order of appending sahi hai kya?
                                                                if($3->type_entry==ARRAY)temp_entry->base_ptr_3ac = $1->temp_3ac;
                                                                append_tac($$, $5);
                                                                get_temp_of_atom_expr($1 ,$$);
                                                        
                                                                append_tac($$, $1);

                                                                if($3->type_data == BOOL && $3->type_entry != ARRAY){
                                                                    quadrup *q = new quadrup();
                                                                    q->gen_quad_variable_decl($5->temp_3ac, $1->temp_3ac);
                                                                    $$->tac_codes.push_back(q);
                                                                
                                                                    $$->tac_str += q->code;


                                                                    if($1->temp_3ac[0]=='*'){
                                                                        quadrup *q = new quadrup();
                                                                        q->gen_quad_variable_decl($1->temp_3ac, "t_"+to_string($$->node_number)+"_temp");
                                                                        $$->tac_codes.push_back(q);
                                                                        $$->tac_str += q->code;

                                                                        q = new quadrup();
             
                                                                    q->gen_quad_operator("t_" + to_string($$->node_number)+"_temp", "0", "t_" + to_string($$->node_number)+"_temp", "!=");
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;
                                                                    

                                                                    q = new quadrup();
                                                                    q->gen_quad_variable_decl("t_" + to_string($$->node_number)+"_temp", $1->temp_3ac);
                                                                   $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;

                                                                    }                                                                     
                                                                    else{  q = new quadrup();
             
                                                                    q->gen_quad_operator($1->temp_3ac, "0", $1->temp_3ac, "!=");
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;
                                                                    }
                                                                }
                                                                else{ quadrup *q = new quadrup();
                                                                    q->gen_quad_variable_decl($5->temp_3ac, $1->temp_3ac);
                                                                    $$->tac_codes.push_back(q);
                                                                
                                                                    $$->tac_str += q->code;
                                                               }
                                                            }
                                                            
                                                        }  
| atom_expr augassign test                              {
                                                            $$ = new node("expr_stmt", false, yylineno, ++node_number);
                                                            add_child($$, $1);
                                                            add_child($$, $2);
                                                            add_child($$, $3);


                                                            if(debug_symbol_table) cout<<"TYPE OF ENTRY OF LHS IS "<<$1->type_entry<<endl;
                                                            if($1->type_entry == CLASS || $1->type_entry == LITERAL || $1->type_entry == FUNCTION){
                                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                cerr<<"ERROR : LHS of assignment cannot be a class or a literal or a function IT IS : "<<entrytype[$1->type_entry]<<endl;
                                                                cerr<<"************************************************************************"<<endl;
                                                                exit(1);
                                                            }
                                                            else { symbol_table_entry* entry = sym_table_lookup($1->atom_name, $1);
                                                            if(debug_symbol_table)cout<<"LOOK_UP: "<<entry->name<< "CLASS OF ENTRY : "<<entry->present_table->name<<endl;
                                                            if($1->type_entry == CLASS || $1->type_entry == LITERAL || $1->type_entry == FUNCTION){
                                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                cerr<<"ERROR : LHS of assignment cannot be a class or a literal or a function IT IS : "<<entrytype[$1->type_entry]<<endl;
                                                                cerr<<"************************************************************************"<<endl;
                                                                exit(1);                                                            
                                                            }
                                                            if(!check_data_type($1->type_data , $3->type_data)){
                                                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                    cerr<<"ERROR : Type checking error "<<endl;
                                                                    cerr<<"************************************************************************"<<endl;
                                                                    exit(1);                                                            
                                                                }
                                                            }
                                                            get_temp_of_atom_expr($1 , $$);
                                                            
                                                            append_tac($$, $3);
                                                            append_tac($$, $1);
                                                             
                                                            string s = $1->temp_3ac;
                                                            string s_original = s;  // for calling STORE later

                                                            if(s[0] == '*'){
                                                                s = s.substr(1); 
                                                            
                                                                quadrup * q = new quadrup();
                                                                q->gen_quad_variable_decl($1->temp_3ac, s + "_" + to_string($$->node_number));
                                                                $$->tac_codes.push_back(q);
                                                                $$->tac_str += q->code;
                                                                $1->temp_3ac = s + "_" + to_string($$->node_number);
                                                            }
                                                            
                                                            quadrup* q = new quadrup();
                                                            q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, $1->temp_3ac,  $2->temp_3ac);
                                                            $$->tac_codes.push_back(q);
                                                            $$->tac_str += q->code;
                                                            $$->temp_3ac = $1->temp_3ac;

                                                            if(s_original[0] == '*') {  // call STORE if dereferenced augassign
                                                                s_original = s_original.substr(1);

                                                                q = new quadrup();
                                                                q->gen_quad_variable_dereference_left($1->temp_3ac, s_original);
                                                                $$->tac_codes.push_back(q);
                                                                $$->tac_str += q->code;
                                                            }
                                                        }
| test                                                  {
                                                            $$ = new node("expr_stmt", false, yylineno, ++node_number);
                                                            add_child($$, $1);
                                                            append_tac($$, $1);
                                                            $$->temp_3ac = $1->temp_3ac;
                                                            
                                                        }
;
 
augassign: "+="                         { 
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_plus_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();

                                        }   
| "-="                                  { 
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_minus_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();

                                        }
| "*="                                  { 
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_multiply_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();

                                        }
| "/="                                  { 
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_divide_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();
                                        }
| "%="                                  { 
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_modulo_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();
                                        }
| "&="                                  { 
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_bitwise_and_equal", true, "&amp;=", 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();
                                        }
| "|="                                  { 
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_bitwise_or_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();
                                        }
| "^="                                  {   
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_bitwise_xor_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();
                                        }
| "<<="                                 { 
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_left_shift_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();
                                        }
| ">>="                                 {   
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_right_shift_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();
                                        }
| "**="                                 {   
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_power_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->temp_3ac = $1;
                                            $$->temp_3ac.pop_back();
                                        }
| "//="                                 {
                                            $$ = new node("augassign", false, yylineno, ++node_number);
                                            node *temp_node = new node("DELIMITER_floor_divide_equal", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            
                                            $$->temp_3ac = $1 ;
                                            $$->temp_3ac.pop_back();
                                        }
;

flow_stmt: 
"break"                                 {
                                            $$ = new node("flow_stmt", false, yylineno, ++node_number);
                                            node *temp_node = new node("KEYWORD_break", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);

                                            $$->exp_str_val = $1;
                                            $$->temp_3ac = $1;

                                            quadrup * q = new quadrup();
                                            q -> gen_quad_goto("break");
                                            $$->tac_codes.push_back(q);
                                            $$->tac_str += q->code;

                                            if(!flow_stmt_check){
                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                cerr << "ERROR : break statement not inside loop" << endl;
                                                cerr<<"************************************************************************"<<endl;
                                                exit(1); 
                                            }
                                        }
|  "continue"                           {
                                            $$ = new node("flow_stmt", false, yylineno, ++node_number);
                                            node *temp_node = new node("KEYWORD_continue", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            quadrup * q = new quadrup();

                                            $$->exp_str_val = $1;
                                            $$->temp_3ac = $1;

                                            q -> gen_quad_goto("continue");
                                            $$->tac_codes.push_back(q);
                                            $$->tac_str += q->code;

                                            if(!flow_stmt_check){
                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                cerr<< "ERROR : continue statement not inside loop" << endl;
                                                cerr<<"************************************************************************"<<endl;
                                                exit(1); 
                                            }

                                        }
|  "return"                             {
                                            $$ = new node("flow_stmt", false, yylineno, ++node_number);
                                            node *temp_node = new node("KEYWORD_return", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            $$->exp_str_val = $1;
                                            $$->temp_3ac = $1;
                                            if(current_symbol_table.top()->return_type != NONE){
                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                cerr<<"ERROR : Function must return a value"<<endl;
                                                cerr<<"************************************************************************"<<endl;
                                                exit(1); 
                                            }
                                            quadrup * q = new quadrup();
                                            q -> gen_quad_return("");
                                            $$->tac_codes.push_back(q);
                                            $$->tac_str += q->code;
                                        }
|  "return" test                        {
                                            $$ = new node("flow_stmt", false, yylineno, ++node_number);
                                            node *temp_node = new node("KEYWORD_return", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            add_child($$, $2);


                                            $$->exp_str_val = $1;
                                            $$->temp_3ac = $1;

                                            append_tac($$, $2);
                                            if(current_symbol_table.top()->return_type == NONE){
                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                cerr<<"Error : Function must not return a value"<<endl;
                                                cerr<<"************************************************************************"<<endl;
                                                exit(1); 
                                            }
                                            else if(!check_data_type(current_symbol_table.top()->return_type, $2->type_data)){
                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                cerr<<"ERROR : Return type mismatch"<<endl;
                                                cerr<<"************************************************************************"<<endl;
                                                exit(1); 
                                            }

                                            quadrup * q = new quadrup();
                                            q -> gen_quad_return($2 -> temp_3ac);
                                            $$->tac_codes.push_back(q);
                                            $$->tac_str += q->code;

                                            //machli check return type through testing 
                                            
                                        } 
;

compound_stmt:  if_stmt                     {
                                                $$ = new node("compound_stmt", false, yylineno, ++node_number);
                                                add_child($$, $1);
                                                append_tac($$, $1);
                                            }
| while_stmt                                {
                                                $$ = new node("compo    und_stmt", false, yylineno, ++node_number);
                                                append_tac($$, $1);
                                                add_child($$, $1);
                                            } 
| for_stmt                                  {
                                                $$ = new node("compound_stmt", false, yylineno, ++node_number);
                                                add_child($$, $1);
                                                append_tac($$, $1);
                                            }     
| funcdef                                   {
                                                $$ = new node("compound_stmt", false, yylineno, ++node_number);
                                                add_child($$, $1);
                                                append_tac($$, $1);
                                            }     
| classdef                                  {
                                                $$ = new node("compound_stmt", false, yylineno, ++node_number);
                                                add_child($$, $1);
                                                append_tac($$, $1);
                                            } 
; 

if_stmt:
"if" test ":" suite                         {
                                                $$ = new node("if_stmt", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_if", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                add_child($$, $2);
                                                temp_node = new node("DELIMITER_colon", true, $3, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                add_child($$, $4);

                                                append_tac($$, $2);
                                                
                                                quadrup * q = new quadrup();
                                                q->gen_quad_if_false($2->temp_3ac, "J+ " + to_string($4->tac_codes.size() + 1));
                                                $$->tac_codes.push_back(q);
                                                $$->tac_str += q->code;

                                                append_tac($$, $4); 

                                            }
| "if" test ":" suite elif_clause_list_opt  {
                                                $$ = new node("if_stmt", false, yylineno, ++node_number);
                                                node *temp_node = new node("KEYWORD_if", true, $1, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                add_child($$, $2);
                                                temp_node = new node("DELIMITER_colon", true, $3, 0, yylineno, ++node_number);
                                                add_child($$, temp_node);
                                                add_child($$, $4);
                                                add_child($$, $5);

                                                // $$->tac_codes.insert( $$->tac_codes.end() , $2->tac_codes.begin() , $2->tac_codes.end());
                                                // $$->tac_str += $2->tac_str;  //free$2ke
                                                append_tac($$, $2);   

                                                quadrup *q = new quadrup();
                                                q -> gen_quad_if_false( $2->temp_3ac, "J+ " + to_string($4->tac_codes.size() + 2));
                                                $$->tac_codes.push_back(q);
                                                $$->tac_str += q->code;

                                                // $$->tac_codes.insert( $$->tac_codes.end() , $4->tac_codes.begin() , $4->tac_codes.end());
                                                // $$->tac_str += $4->tac_str;  //free$4ke
                                                append_tac($$, $4);

                                                q = new quadrup();
                                                q -> gen_quad_goto("J+ " + to_string($5 -> tac_codes.size() +1));
                                                $$->tac_codes.push_back(q);
                                                $$->tac_str += q->code;

                                                // $$->tac_codes.insert( $$->tac_codes.end() , $5->tac_codes.begin() , $5->tac_codes.end());
                                                // $$->tac_str += $5->tac_str;  //free$5ke
                                                append_tac($$, $5);

                                            }
| "if" test ":" suite "else" ":" suite  {
                                            $$ = new node("if_stmt", false, yylineno, ++node_number);
                                            node *temp_node = new node("KEYWORD_if", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            add_child($$, $2);
                                            temp_node = new node("DELIMITER_colon", true, $3, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            add_child($$, $4);
                                            temp_node = new node("KEYWORD_else", true, $5, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            temp_node = new node("DELIMITER_colon", true, $6, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            add_child($$, $7);

                                            // $$->tac_codes.insert( $$->tac_codes.end() , $2->tac_codes.begin() , $2->tac_codes.end());
                                            // $$->tac_str += $2->tac_str;  //free$2ke
                                            append_tac($$, $2);                             // printed
                                            
                                            quadrup * q = new quadrup();
                                            q->gen_quad_if_false($2->temp_3ac, "J+ " + to_string($4->tac_codes.size() + 2));
                                            $$->tac_codes.push_back(q);
                                            $$->tac_str += q->code;

                                            // $$->tac_codes.insert( $$->tac_codes.end() , $4->tac_codes.begin() , $4->tac_codes.end());
                                            // $$->tac_str += $4->tac_str;  //free$2ke
                                            append_tac($$, $4);
                                            
                                            q = new quadrup();
                                            q->gen_quad_goto("J+ " + to_string($7->tac_codes.size() + 1));
                                            $$->tac_codes.push_back(q);
                                            $$->tac_str += q->code;
                                            
                                            int tot_size = $4->tac_codes.size();
                                            for(int i = tot_size - 1; i >= 0; i--) {
                                                auto q = $4->tac_codes[i];
                                                string prefix = "IF_FALSE ";
                                                if((q->code).compare(0, prefix.size(), prefix) == 0 && q->reljump_else){
                                                    // cout << "1 ::-:: " << q->rel_jump << endl;                                                                
                                                    // q->rel_jump += 1;
                                                    // cout << "2 ::-: " << q->rel_jump << endl;
                                                    q->reljump_else = false;
                                                    break;
                                                }
                                            }

                                            // $$->tac_codes.insert( $$->tac_codes.end() , $7->tac_codes.begin() , $7->tac_codes.end());
                                            // $$->tac_str += $7->tac_str;  //free$2ke
                                            append_tac($$, $7);
                                        }
| "if" test ":" suite elif_clause_list_opt "else" ":" suite     {
                                                                    $$ = new node("if_stmt", false, yylineno, ++node_number);
                                                                    node *temp_node = new node("KEYWORD_if", true, $1, 0, yylineno, ++node_number);
                                                                    add_child($$, temp_node);
                                                                    add_child($$, $2);
                                                                    temp_node = new node("DELIMITER_colon", true, $3, 0, yylineno, ++node_number);
                                                                    add_child($$, temp_node);
                                                                    add_child($$, $4);
                                                                    add_child($$, $5);
                                                                    temp_node = new node("KEYWORD_else", true, $6, 0, yylineno, ++node_number);
                                                                    add_child($$, temp_node);
                                                                    temp_node = new node("DELIMITER_colon", true, $7, 0, yylineno, ++node_number);
                                                                    add_child($$, temp_node);
                                                                    add_child($$, $8);


                                                                    // $$->tac_codes.insert( $$->tac_codes.end() , $2->tac_codes.begin() , $2->tac_codes.end());
                                                                    // $$->tac_str += $2->tac_str;  //free$2ke
                                                                    append_tac($$, $2);

                                                                    quadrup *q = new quadrup();
                                                                    q -> gen_quad_if_false($2 -> temp_3ac, "J+ " + to_string($4->tac_codes.size() + 2));
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;

                                                                    // $$->tac_codes.insert( $$->tac_codes.end() , $4->tac_codes.begin() , $4->tac_codes.end());
                                                                    // $$->tac_str += $4->tac_str;  //free$4ke
                                                                    append_tac($$, $4);

                                                                    q = new quadrup();
                                                                    q -> gen_quad_goto("J+ " + to_string($5 -> tac_codes.size() + $8->tac_codes.size() + 2));
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;

                                                                    // $$->tac_codes.insert( $$->tac_codes.end() , $5->tac_codes.begin() , $5->tac_codes.end());
                                                                    // $$->tac_str += $5->tac_str;  //free$5ke

                                                                    //work need to be done here -> add size of else's suite to each GOTO and last GOTO of elif_clause_list_opt
                                                                    int tot_size = $5->tac_codes.size();
                                                                    for(int i = 0; i < tot_size; i++) {
                                                                        auto (&q) = $5->tac_codes[i];
                                                                        if(q->code == "GOTO "){
                                                                            cout << "1 :::: " << q->rel_jump << endl;                                                                
                                                                            q->rel_jump += ($8->tac_codes.size() + 1);
                                                                            cout << "2 ::: " << q->rel_jump << endl;
                                                                        }
                                                                    }

                                                                    // also need to add 1 to last last IF_FALSE GOTO of elif_clause_list_opt

                                                                    for(int i = tot_size - 1; i >= 0; i--) {
                                                                        auto q = $5->tac_codes[i];
                                                                        string prefix = "IF_FALSE ";
                                                                        if((q->code).compare(0, prefix.size(), prefix) == 0 && q->reljump_else){
                                                                            cout << "1 ::-:: " << q->rel_jump << endl;                                                                
                                                                            q->rel_jump += 1;
                                                                            cout << "2 ::-: " << q->rel_jump << endl;
                                                                            q->reljump_else = false;
                                                                            break;
                                                                        }
                                                                    }

                                                                    append_tac($$, $5);

                                                                    q = new quadrup();
                                                                    q -> gen_quad_goto("J+ " + to_string($8->tac_codes.size() + 1));
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;

                                                                    // $$->tac_codes.insert( $$->tac_codes.end() , $8->tac_codes.begin() , $8->tac_codes.end());
                                                                    // $$->tac_str += $8->tac_str;  //free$8ke
                                                                    append_tac($$, $8);
                                                                }
;

elif_clause_list_opt: "elif" test ":" suite             {
                                                            $$ = new node("elif_clause_list_opt", false, yylineno, ++node_number);
                                                            node *temp_node = new node("KEYWORD_elif", true, $1, 0, yylineno, ++node_number);
                                                            add_child($$, temp_node);
                                                            add_child($$, $2);
                                                            temp_node = new node("DELIMITER_colon", true, $3, 0, yylineno, ++node_number);
                                                            add_child($$, temp_node);
                                                            add_child($$, $4);

                                                            // $$->tac_codes.insert( $$->tac_codes.end() , $2->tac_codes.begin() , $2->tac_codes.end());
                                                            // $$->tac_str += $2->tac_str;  //free$2ke
                                                            append_tac($$, $2);

                                                            quadrup *q = new quadrup();
                                                            q -> gen_quad_if_false($2->temp_3ac, "J+ " + to_string($4->tac_codes.size() + 1));
                                                            $$->tac_codes.push_back(q);
                                                            $$->tac_str += q->code;
                                                            q -> reljump_else = true;
                                                            // $$->tac_codes.insert( $$->tac_codes.end() , $4->tac_codes.begin() , $4->tac_codes.end());
                                                            // $$->tac_str += $4->tac_str;  //free$4ke
                                                            append_tac($$, $4);

                                                        }
| "elif" test ":" suite elif_clause_list_opt    {
                                                    $$ = new node("elif_clause_list_opt", false, yylineno, ++node_number);
                                                    node *temp_node = new node("KEYWORD_elif", true, $1, 0, yylineno, ++node_number);
                                                    add_child($$, temp_node);
                                                    add_child($$, $2);
                                                    temp_node = new node("DELIMITER_colon", true, $3, 0, yylineno, ++node_number);
                                                    add_child($$, temp_node);
                                                    add_child($$, $4);
                                                    add_child($$, $5);

                                                    // $$->tac_codes.insert( $$->tac_codes.end() , $2->tac_codes.begin() , $2->tac_codes.end());
                                                    // $$->tac_str += $2->tac_str;  //free$2ke
                                                    append_tac($$, $2);

                                                    quadrup *q = new quadrup();
                                                    q -> gen_quad_if_false($2->temp_3ac, "J+ " + to_string($4->tac_codes.size() + 2));
                                                    $$->tac_codes.push_back(q);

                                                    // $$->tac_codes.insert( $$->tac_codes.end() , $4->tac_codes.begin() , $4->tac_codes.end());
                                                    // $$->tac_str += $4->tac_str;  //free$4ke
                                                    append_tac($$, $4);

                                                    q = new quadrup();
                                                    q -> gen_quad_goto("J+ " + to_string($5 -> tac_codes.size() + 1));
                                                    $$->tac_codes.push_back(q);
                                                    $$->tac_str += q->code;

                                                    // $$->tac_codes.insert( $$->tac_codes.end() , $5->tac_codes.begin() , $5->tac_codes.end());
                                                    // $$->tac_str += $5->tac_str;  //free$5ke
                                                    append_tac($$, $5);
                                                }
;


while_decl : "while" { flow_stmt_check = true;
                      nested_loop_cnt++;
                      $$ = new node("while_decl", false, yylineno, ++node_number);
                      node *temp_node = new node("KEYWORD_while", true, $1, 0, yylineno, ++node_number);
                      add_child($$, temp_node); }
;


while_stmt:
while_decl test ":" suite                              {
                                                        $$ = new node("while_stmt", false, yylineno, ++node_number);
                                                        add_child($$, $1);
                                                        add_child($$, $2);
                                                        node *temp_node = new node("DELIMITER_colon", true, $3, 0, yylineno, ++node_number);
                                                        add_child($$, temp_node);
                                                        add_child($$, $4);

                                                        // $$->tac_codes.insert( $$->tac_codes.end() , $2->tac_codes.begin() , $2->tac_codes.end());
                                                        // $$->tac_str += $2->tac_str;  //free$2ke
                                                        int size = $2 -> tac_codes.size();
                                                        append_tac($$, $2);

                                                        quadrup *q = new quadrup();
                                                        q -> gen_quad_if_false($2->temp_3ac, "J+ " + to_string($4->tac_codes.size() + 2));
                                                        $$->tac_codes.push_back(q);
                                                        $$->tac_str += q->code;

                                                        // $$->tac_codes.insert( $$->tac_codes.end() , $4->tac_codes.begin() , $4->tac_codes.end());
                                                        // $$->tac_str += $4->tac_str;  //free$4ke

                                                        // addded by @krish
                                                        int count_before_break = 0;
                                                        int tot_size = $4->tac_codes.size();
                                                        for(int i = 0; i < tot_size; i++) {
                                                            auto (&q) = $4->tac_codes[i];
                                                            if(q->is_break) {
                                                                q->gen_quad_goto("J+ " + to_string(tot_size - count_before_break + 1));
                                                                q->is_break = false;
                                                            }
                                                            if(q->is_continue){
                                                                q->gen_quad_goto("J+ " + to_string(tot_size - count_before_break));
                                                                q->is_continue = false;
                                                            }
                                                            count_before_break++;
                                                        }
                                                        size += $4->tac_codes.size();
                                                        append_tac($$, $4);

                                                        q = new quadrup();
                                                        q -> gen_quad_goto("J- " + to_string(size + 1));
                                                        $$->tac_codes.push_back(q);
                                                        $$->tac_str += q->code;

                                                        if(nested_loop_cnt == 1)flow_stmt_check = false;
                                                        nested_loop_cnt--;
                                                    }
| while_decl test ":" suite "else" ":" suite           {
                                                        $$ = new node("while_stmt", false, yylineno, ++node_number);
                                                        add_child($$, $1);
                                                        add_child($$, $2);
                                                        node *temp_node = new node("DELIMITER_colon", true, $3, 0, yylineno, ++node_number);
                                                        add_child($$, temp_node);
                                                        add_child($$, $4);
                                                        temp_node = new node("KEYWORD_else", true, $5, 0, yylineno, ++node_number);
                                                        add_child($$, temp_node);
                                                        temp_node = new node("DELIMITER_colon", true, $6, 0, yylineno, ++node_number);
                                                        add_child($$, temp_node);
                                                        add_child($$, $7);

                                                        int size = $2 -> tac_codes.size();
                                                        append_tac($$, $2);
                                                        

                                                        quadrup *q = new quadrup();
                                                        q -> gen_quad_if_false($2 -> temp_3ac, "J+ " + to_string($4->tac_codes.size() + 2));
                                                        $$->tac_codes.push_back(q);
                                                        $$->tac_str += q->code;

                                                        // $$->tac_codes.insert( $$->tac_codes.end() , $4->tac_codes.begin() , $4->tac_codes.end());
                                                        // $$->tac_str += $4->tac_str;  //free$4ke

                                                        int count_before_break = 0;
                                                        int tot_size = $4->tac_codes.size();
                                                        for(auto &q : $4->tac_codes){
                                                            if(q->is_break){
                                                                q->gen_quad_goto("J+ " + to_string(tot_size - count_before_break + 1));
                                                                q->is_break = false;
                                                            }
                                                            if(q->is_continue){
                                                                q->gen_quad_goto("J+ " + to_string( tot_size - count_before_break));
                                                                q->is_continue = false;

                                                            }
                                                            count_before_break++;
                                                        }

                                                        size += $4->tac_codes.size();
                                                        append_tac($$, $4);

                                                        q = new quadrup();
                                                        q -> gen_quad_goto("J- " + to_string(size + 1));
                                                        $$->tac_codes.push_back(q);
                                                        $$->tac_str += q->code;

                                                        // $$->tac_codes.insert( $$->tac_codes.end() , $7->tac_codes.begin() , $7->tac_codes.end());
                                                        // $$->tac_str += $7->tac_str;  //free$7ke
                                                        append_tac($$, $7);

                                                        if(nested_loop_cnt == 1)flow_stmt_check = false;
                                                        nested_loop_cnt--;

                                                    }
;

for_decl : "for" {flow_stmt_check = true;
                  nested_loop_cnt++;
                  $$ = new node("for_decl", false, yylineno, ++node_number);
                  node *temp_node = new node("KEYWORD_for", true, $1, 0, yylineno, ++node_number);
                  add_child($$, temp_node);
}

for_stmt:
for_decl NAME "in" atom_expr ":" suite  {
                                            $$ = new node("for_stmt", false, yylineno, ++node_number);
                                            add_child($$, $1);
                                            
                                            node *temp_node1 = new node("NAME", true, $2, 0, yylineno, ++node_number);
                                            add_child($$, temp_node1);
                                            node *temp_node = new node("KEYWORD_in", true, $3, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            add_child($$, $4);
                                            temp_node = new node("DELIMITER_colon", true, $5, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            add_child($$, $6);
                                            
                                            // Quadruple generation
                                            string start;
                                            string end;
                                            vector<string>name = $4->atom_name;

                                            if(name[0] == "range"){
                                                int size = $4 -> tac_codes.size();
                                                append_tac($$, $4);
                                                // cerr<<"in range"<<$4->args[0]->temp_3ac<<" "<<name[1]<<" "<<$4->args[0]->atom_test->lexeme<<endl;
                                               
                                                string ap = $4->args[0]->atom_test->lexeme;
                                                if(ap == "len") size -= 2;
                                                if($4->args.size() == 1){
                                                    start = "0";
                                                    end = $4->args[0]->temp_3ac;
                                                }
                                                else if($4->args.size() == 2){
                                                    string ap2 = $4->args[1]->atom_test->lexeme;
                                                    if(ap2 == "len") size -= 2;
                                                    start = $4->args[0]->temp_3ac;
                                                    end = $4->args[1]->temp_3ac;
                                                }
                                                else{
                                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                    cerr<<"ERROR : For loop can only be used with range"<<endl;
                                                    cerr<<"************************************************************************"<<endl;
                                                    exit(1); 
                                                }
                                                quadrup *q = new quadrup();
                                                q->gen_quad_variable_decl( (start) , $2);
                                                $$->tac_codes.push_back(q);
                                                $$->tac_str += q->code;

                                                q = new quadrup();
                                                q->gen_quad_operator( $2 , (end) , "t_"+to_string(temp_node1->node_number) , "<");
                                                $$->tac_codes.push_back(q);
                                                $$->tac_str += q->code;

                                                q = new quadrup();
                                                q -> gen_quad_if_false("t_" + to_string(temp_node1->node_number), "J+ " + to_string($6->tac_codes.size() + 3));
                                                $$->tac_codes.push_back(q);
                                                $$->tac_str += q->code;


                                                int count_before_break = 0;
                                                int tot_size = $6->tac_codes.size();
                                                if(debug_symbol_table) cout<<" FOR_STMT : SIZE OF TAC CODES : "<<tot_size<<endl;
                                                for(auto &q : $6->tac_codes){
                                
                                                    if(q->is_break){
                                                        q->gen_quad_goto("J+ " + to_string(tot_size - count_before_break + 2));
                                                        q->is_break = false;
                                                        if(debug_symbol_table) cout<<"GOTO BREAK FOUND GAP : "<<tot_size - count_before_break + 1<<endl;
                                                    }
                                                    if(q->is_continue){
                                                        q->gen_quad_goto("J+ " + to_string(tot_size - count_before_break));
                                                        q->is_continue = false;
                                                        if(debug_symbol_table) cout<<"GOTO CONTINUE FOUND GAP : "<<tot_size - count_before_break<<endl;
                                                    }
                                                    count_before_break++;
                                                }
                                                size += $6->tac_codes.size();
                                                append_tac($$, $6);
                                                q = new quadrup();
                                                q->gen_quad_operator( $2 , "1" , $2 , "+");
                                                $$->tac_codes.push_back(q);
                                                $$->tac_str += q->code;

                                                q = new quadrup();
                                                q -> gen_quad_goto("J- " + to_string(size + 3));
                                                $$->tac_codes.push_back(q);
                                                $$->tac_str += q->code;

                                                if(nested_loop_cnt == 1)flow_stmt_check = false;
                                                nested_loop_cnt--;

                                        } else {
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Error : For loop can only be used with range"<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1); 
                                        }


                                    }
| for_decl NAME "in" atom_expr ":"  suite "else" ":" suite     {
                                                                $$ = new node("for_stmt", false, yylineno, ++node_number);
                                                                add_child($$, $1);
                                                                node * temp_node1 = new node("NAME", true, $2, 0, yylineno, ++node_number);
                                                                add_child($$, temp_node1);
                                                                node *temp_node = new node("KEYWORD_in", true, $3, 0, yylineno, ++node_number);
                                                                add_child($$, temp_node);
                                                                add_child($$, $4);
                                                                temp_node = new node("DELIMITER_colon", true, $5, 0, yylineno, ++node_number);
                                                                add_child($$, temp_node);
                                                                add_child($$, $6);
                                                                temp_node = new node("KEYWORD_else", true, $7, 0, yylineno, ++node_number);
                                                                add_child($$, temp_node);
                                                                temp_node = new node("DELIMITER_colon", true, $8, 0, yylineno, ++node_number);
                                                                add_child($$, temp_node);
                                                                add_child($$, $9);


                                                                string start;
                                                                string end;
                                                                vector<string>name = $4->atom_name;
                                                                if(name[0]=="range"){
                                                                    int size = $4 -> tac_codes.size();
                                                                    append_tac($$, $4);
                                                                    // cerr<<"in range"<<$4->args[0]->temp_3ac<<" "<<name[1]<<" "<<$4->args[0]->atom_test->lexeme<<endl;
                                                                
                                                                    string ap = $4->args[0]->atom_test->lexeme;
                                                                    if(ap=="len") size -= 2;
                                                                    if($4->args.size()==1){
                                                                        start = "0";
                                                                        end = $4->args[0]->temp_3ac;
                                                                    }
                                                                    else if($4->args.size()==2){
                                                                        string ap2 = $4->args[1]->atom_test->lexeme;
                                                                        if(ap2 == "len") size -= 2;
                                                                        start = $4->args[0]->temp_3ac;
                                                                        end = $4->args[1]->temp_3ac;
                                                                    }
                                                                    else{
                                                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                        cerr<<"Error : For loop can only be used with range"<<endl;
                                                                        cerr<<"************************************************************************"<<endl;
                                                                        exit(1); 
                                                                    }
                                                                    quadrup *q = new quadrup();
                                                                    q->gen_quad_variable_decl( (start) , $2);
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;

                                                                    


                                                                    q = new quadrup();                                                        
                                                                    // $$->tac_codes.insert( $$->tac_codes.end() , $7->tac_codes.begin() , $7->tac_codes.end());
                                                                    // $$->tac_str += $7->tac_str;  //free$7ke

                                                                    q->gen_quad_operator( $2 , (end) , "t_"+to_string(temp_node1->node_number) , "<");
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;

                                                                    q = new quadrup();
                                                                    q -> gen_quad_if_false("t_" + to_string(temp_node1->node_number), "J+ " + to_string($6->tac_codes.size() + 3));
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;

                                                                    // $$->tac_codes.insert( $$->tac_codes.end() , $6->tac_codes.begin() , $6->tac_codes.end());
                                                                    // $$->tac_str += $6->tac_str;  //free$4ke

                                                                    int count_before_break = 0;
                                                                    int tot_size = $6->tac_codes.size();
                                                                    for(auto &q : $6->tac_codes) {
                                                                        if(q->is_break){
                                                                            q->gen_quad_goto("J+ " + to_string(tot_size - count_before_break + 2));
                                                                            q->is_break = false;
                                                                        }
                                                                        if(q->is_continue){
                                                                            q->gen_quad_goto("J+ " + to_string(tot_size - count_before_break));
                                                                            q->is_continue = false;
                                                                        }
                                                                        count_before_break++;
                                                                    }
                                                                    size += $6->tac_codes.size();
                                                                    append_tac($$, $6);

                                                                    q = new quadrup();
                                                                    q->gen_quad_operator( $2 , "1" , $2 , "+");
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;

                                                                    q = new quadrup();
                                                                    q -> gen_quad_goto("J- " + to_string(size + 3));
                                                                    $$->tac_codes.push_back(q);
                                                                    $$->tac_str += q->code;



                                                                    // $$->tac_codes.insert( $$->tac_codes.end() , $9->tac_codes.begin() , $9->tac_codes.end());
                                                                    // $$->tac_str += $9->tac_str;  //free$7ke
                                                                    append_tac($$, $9);

                                                                    if(nested_loop_cnt == 1)flow_stmt_check = false;
                                                                    nested_loop_cnt--;
                
                                                                } else {
                                                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                                    cerr<<"Error : For loop can only be used with range"<<endl;
                                                                    cerr<<"************************************************************************"<<endl;
                                                                    exit(1); 
                                                                }
                                                        
                                                            }                                                            
;


stmt_STAR:  stmt           {
                                $$ = new node("stmt_STAR", false, yylineno, ++node_number);
                                add_child($$, $1);
                                append_tac($$, $1);
                            }
| NEWLINE                   {
                                $$ = new node("stmt_STAR", false, yylineno, ++node_number);                           
                            }
| stmt_STAR stmt            {
                                $$ = new node("stmt_STAR", false, yylineno, ++node_number);
                                add_child($$, $1);
                                add_child($$, $2);

                                append_tac($$, $1);
                                append_tac($$, $2);

                            }
| stmt_STAR NEWLINE         {$$ = new node("stmt_STAR", false, yylineno, ++node_number);
                            add_child($$, $1);
                            append_tac($$, $1);
                            }
;

suite: simple_stmt          {
                                $$ = new node("suite", false, yylineno, ++node_number);
                                add_child($$, $1);
                                append_tac($$, $1);
                            }
| NEWLINE INDENT stmt_STAR DEDENT      {
                                            $$ = new node("suite", false, yylineno, ++node_number);
                                            add_child($$, $3);
                                            append_tac($$, $3);
                                        }
;

test: and_test          {
                            $$ = new node("test", false, yylineno, ++node_number);
                            add_child($$, $1);
                            $$->atom_test = $1->atom_test;
                            $$->type_entry = $1->type_entry;
                            $$->type_data = $1->type_data;
                            $$->array_types = $1->array_types;
                            append_tac($$, $1);
                            $$->temp_3ac = $1->temp_3ac;
                            
                        }
| and_test "or" test    {   
                            $$ = new node("test", false, yylineno, ++node_number);
                            add_child($$, $1);
                            node *temp_node = new node("KEYWORD_or", true, $2, 0, yylineno, ++node_number);
                            add_child($$, temp_node);
                            add_child($$, $3);

                            $$->type_data = BOOL;
                            $$->type_entry = $1->type_entry;
                            if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Error IN TYPE CHECKING ADD"<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1); 
                            }
                            append_tac($$, $1);
                            append_tac($$, $3);

                            quadrup * q = new quadrup();
                            q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "or");
                            $$->tac_codes.push_back(q);
                            $$->tac_str += q->code;

                            $$->temp_3ac = "t_"+to_string($$->node_number);

                        }
;

and_test:
not_test                                {    
                                            $$ = new node("and_test", false, yylineno, ++node_number);
                                            add_child($$, $1);
                                            $$->atom_test = $1->atom_test;
                                            $$->type_entry = $1->type_entry;
                                            $$->type_data = $1->type_data;
                                            $$->array_types = $1->array_types;
                                            append_tac($$, $1);
                                    
                                            $$->temp_3ac = $1->temp_3ac;
                                        }
| not_test "and" and_test               {
                                            $$ = new node("and_test", false, yylineno, ++node_number);
                                            add_child($$, $1);
                                            node *temp_node = new node("KEYWORD_and", true, $2, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            add_child($$, $3);

                                            append_tac($$, $1);
                                            append_tac($$, $3);

                                            $$->type_data = BOOL;
                                            $$->type_entry = $3->type_entry;
                                            if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                cerr<<"Error IN TYPE CHECKING ADD"<<endl;
                                                cerr<<"************************************************************************"<<endl;
                                                exit(1);
                                            }
                                            quadrup * q = new quadrup();
                                            q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "and");
                                            $$->tac_codes.push_back(q);
                                            $$->tac_str += q->code;

                                            $$->temp_3ac = "t_"+to_string($$->node_number);
                                        }
;

not_test: 
"not" not_test                          {
                                            $$ = new node("not_test", false, yylineno, ++node_number);
                                            node *temp_node = new node("KEYWORD_not", true, $1, 0, yylineno, ++node_number);
                                            add_child($$, temp_node);
                                            add_child($$, $2);
                                            
                                            $$->type_data = BOOL;
                                            $$->type_entry = $2->type_entry;
                                            if($2->type_entry == ARRAY){
                                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                                cerr<<"Error IN TYPE CHECKING ADD"<<endl;
                                                cerr<<"************************************************************************"<<endl;
                                                exit(1);
                                            }
                                            append_tac($$, $2);
                                            quadrup * q = new quadrup();
                                            q->gen_quad_operator("", $2->temp_3ac,  "t_"+to_string($$->node_number), "not");
                                            $$->tac_codes.push_back(q);
                                            $$->tac_str += q->code;
                                            
                                            $$->temp_3ac = "t_"+to_string($$->node_number);

                                        }
| comparison                            {
                                            $$ = new node("not_test", false, yylineno, ++node_number);
                                            add_child($$, $1);
                                            $$->atom_test = $1->atom_test;
                                            $$->type_entry = $1->type_entry;
                                            $$->type_data = $1->type_data;
                                            $$->array_types = $1->array_types;
                                            append_tac($$, $1);

                                            $$->temp_3ac = $1->temp_3ac;
                                        }
;

comparison:
 expr "<" comparison  { $$ = new node("comparison", false, yylineno, ++node_number);
                        add_child($$, $1);
                        node *temp_node = new node("OPERATOR_less_than", true, "&lt;", 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        add_child($$, $3);

                        $$->type_data = BOOL;
                        $$->type_entry = $1->type_entry;
                        if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                            cerr<<"Error IN TYPE CHECKING ADD"<<endl;
                            cerr<<"************************************************************************"<<endl;
                            exit(1);
                        }
                        if(!check_data_type($1->type_data, $3->type_data)){
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Incompatible types for < "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1); 
                        }

                        append_tac($$, $1);
                        append_tac($$, $3);

                        if($1 -> type_data == STRING && $3 -> type_data == STRING){
                            quadrup * q = new quadrup();
                            q->gen_func_push_param_strcmp($1 -> temp_3ac, $3 -> temp_3ac);
                            $$->tac_codes.push_back(q);
                            $$->tac_str += q->code;
                            // q = new quadrup();
                            // q->gen_func_push_param_strcmp($3 -> temp_3ac);
                            // $$->tac_codes.push_back(q);
                            // // $$->tac_str += q->code;
                            // q = new quadrup();
                            // q->gen_quad_stack_pointer("-16");
                            // $$->tac_codes.push_back(q);
                            // $$->tac_str += q->code;
                            // q = new quadrup();
                            // // q->gen_func_call("strcmp");
                            // $$->tac_codes.push_back(q);
                            // $$->tac_str += q->code;
                            // q = new quadrup();
                            // q->gen_quad_stack_pointer("+16");
                            // $$->tac_codes.push_back(q);
                            // $$->tac_str += q->code;
                            q = new quadrup();
                            q->gen_func_get_retval_strcmp("t_"+to_string($$->node_number));
                            $$->tac_codes.push_back(q);
                            $$->tac_str += q->code;
                            q = new quadrup();
                            q->gen_quad_operator("t_"+to_string($$->node_number), "0", "t_"+to_string($$->node_number), "<");    
                            $$->tac_codes.push_back(q);
                            $$->tac_str += q->code;
                        }
                        else{
                            quadrup * q = new quadrup();
                            q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "<");
                            $$->tac_codes.push_back(q);
                            $$->tac_str += q->code;
                        }
                        
                        $$->temp_3ac = "t_"+to_string($$->node_number);
                        }
 | expr ">" comparison  {   $$ = new node("comparison", false, yylineno, ++node_number);
                            add_child($$, $1);
                            node *temp_node = new node("OPERATOR_greater_than", true, "&gt;", 0, yylineno, ++node_number);
                            add_child($$, temp_node);
                            add_child($$, $3);

                            $$->type_data = BOOL;
                            $$->type_entry = $1->type_entry;
                            if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Operator > not supported for array "<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1);
                            }
                            if(!check_data_type($1->type_data, $3->type_data)){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Incompatible types for > "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1); 
                            }
                            append_tac($$, $1);
                            append_tac($$, $3);

                            if($1 -> type_data == STRING && $3 -> type_data == STRING){
                                quadrup * q = new quadrup();
                                q->gen_func_push_param_strcmp($1 -> temp_3ac, $3 -> temp_3ac);
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                // q = new quadrup();
                                // // q->gen_func_push_param_strcmp($3 -> temp_3ac);
                                // // $$->tac_codes.push_back(q);
                                // // $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_quad_stack_pointer("-16");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // // q->gen_func_call("strcmp");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_quad_stack_pointer("+16");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                q = new quadrup();
                                q->gen_func_get_retval_strcmp("t_"+to_string($$->node_number));
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                q = new quadrup();
                                q->gen_quad_operator("t_"+to_string($$->node_number), "0", "t_"+to_string($$->node_number), ">");    
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                            }
                            else{
                                quadrup * q = new quadrup();
                                q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), ">");
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                            }

                            $$->temp_3ac = "t_"+to_string($$->node_number);
                        }
 | expr "==" comparison  {  $$ = new node("comparison", false, yylineno, ++node_number);
                            add_child($$, $1);
                            node *temp_node = new node("OPERATOR_equal", true, $2, 0, yylineno, ++node_number);
                            add_child($$, temp_node);
                            add_child($$, $3);

                            $$->type_data = BOOL;
                            $$->type_entry = $1->type_entry;
                            if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Operator == not supported for array "<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1);
                            }
                            if(!check_data_type($1->type_data, $3->type_data)){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Incompatible types for == "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1); 
                            }

                            append_tac($$, $1);
                            append_tac($$, $3);
                            if($1 -> type_data == STRING && $3 -> type_data == STRING){
                                quadrup * q = new quadrup();
                                cerr<<" INSIDE STRCMP "<<$1->temp_3ac<<" "<<$3->temp_3ac<<endl;
                                q->gen_func_push_param_strcmp($1 -> temp_3ac, $3 -> temp_3ac);
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_func_push_param_strcmp($3 -> temp_3ac);
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_quad_stack_pointer("-16");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // // q->gen_func_call("strcmp");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_quad_stack_pointer("+16");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                q = new quadrup();
                                q->gen_func_get_retval_strcmp("t_"+to_string($$->node_number));
                                
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                q = new quadrup();
                                q->gen_quad_operator("t_"+to_string($$->node_number), "0", "t_"+to_string($$->node_number), "==");    
                                
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                            }
                            else{
                                quadrup * q = new quadrup();
                                q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "==");
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                            }

                            $$->temp_3ac = "t_"+to_string($$->node_number);

                            }
    | expr ">=" comparison  {$$ = new node("comparison", false, yylineno, ++node_number);
                            add_child($$, $1);
                            node *temp_node = new node("OPERATOR_greater_than_or_equal", true, "&gt;=", 0, yylineno, ++node_number);
                            add_child($$, temp_node);
                            add_child($$, $3);

                            $$->type_data = BOOL;
                            $$->type_entry = $1->type_entry;
                            if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Operator >= not supported for array "<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1);
                            }
                            if(!check_data_type($1->type_data, $3->type_data)){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Incompatible types for >= "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1); 
                            }

                            append_tac($$, $1);
                            append_tac($$, $3);

                            if($1 -> type_data == STRING && $3 -> type_data == STRING){
                                quadrup * q = new quadrup();
                                q->gen_func_push_param_strcmp($1 -> temp_3ac, $3 -> temp_3ac);
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_func_push_param_strcmp($3 -> temp_3ac);
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_quad_stack_pointer("-16");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // // q->gen_func_call("strcmp");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_quad_stack_pointer("+16");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                q = new quadrup();
                                q->gen_func_get_retval_strcmp("t_"+to_string($$->node_number));
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                q = new quadrup();
                                q->gen_quad_operator("t_"+to_string($$->node_number), "0", "t_"+to_string($$->node_number), ">=");    
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                            }
                            else{
                                quadrup * q = new quadrup();
                                q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), ">=");
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                            }

                            $$->temp_3ac = "t_"+to_string($$->node_number);
                            }
    | expr "<=" comparison  {
                                $$ = new node("comparison", false, yylineno, ++node_number);
                                add_child($$, $1);
                                node *temp_node = new node("OPERATOR_less_than_or_equal", true, "&lt;=", 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                add_child($$, $3);

                                $$->type_data = BOOL;
                                $$->type_entry = $1->type_entry;
                                if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                    cerr<<"Operator <= not supported for array "<<endl;
                                    cerr<<"************************************************************************"<<endl;
                                    exit(1);
                                }
                                if(!check_data_type($1->type_data, $3->type_data)){
                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                    cerr<<"Incompatible types for <= "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                    cerr<<"************************************************************************"<<endl;
                                    exit(1); 
                                }
                                append_tac($$, $1);
                                append_tac($$, $3);

                                if($1 -> type_data == STRING && $3 -> type_data == STRING){
                                quadrup * q = new quadrup();
                                q->gen_func_push_param_strcmp($1 -> temp_3ac, $3 -> temp_3ac);
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_func_push_param_strcmp($3 -> temp_3ac);
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_quad_stack_pointer("-16");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // // q->gen_func_call("strcmp");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_quad_stack_pointer("+16");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                q = new quadrup();
                                q->gen_func_get_retval_strcmp("t_"+to_string($$->node_number));
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                q = new quadrup();
                                q->gen_quad_operator("t_"+to_string($$->node_number), "0", "t_"+to_string($$->node_number), "<=");    
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                            }
                            else{
                                quadrup * q = new quadrup();
                                q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "<=");
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                            }

                                $$->temp_3ac = "t_"+to_string($$->node_number);
                            }
    | expr "!=" comparison  {
                                $$ = new node("comparison", false, yylineno, ++node_number);
                                add_child($$, $1);
                                node *temp_node = new node("OPERATOR_not_equal", true, $2, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                add_child($$, $3);

                                $$->type_data = BOOL;
                                $$->type_entry = $1->type_entry;
                                if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                    cerr<<"Operator != not supported for array "<<endl;
                                    cerr<<"************************************************************************"<<endl;
                                    exit(1);
                                }
                                append_tac($$, $1);
                                append_tac($$, $3);
                                if(!check_data_type($1->type_data, $3->type_data)){
                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                    cerr<<"Incompatible types for != "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                    cerr<<"************************************************************************"<<endl;
                                    exit(1); 
                                }
                                if($1 -> type_data == STRING && $3 -> type_data == STRING){
                                quadrup * q = new quadrup();
                                q->gen_func_push_param_strcmp($1 -> temp_3ac, $3 -> temp_3ac);
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_func_push_param_strcmp($3 -> temp_3ac);
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_quad_stack_pointer("-16");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // // q->gen_func_call("strcmp");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                // q = new quadrup();
                                // q->gen_quad_stack_pointer("+16");
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                q = new quadrup();
                                q->gen_func_get_retval_strcmp("t_"+to_string($$->node_number));
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                q = new quadrup();
                                q->gen_quad_operator("t_"+to_string($$->node_number), "0", "t_"+to_string($$->node_number), "!=");    
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                            }
                            else{
                                quadrup * q = new quadrup();
                                q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "!=");
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                            }
                                    
                                    $$->temp_3ac = "t_"+to_string($$->node_number);
                            }
    | expr "in" comparison  {
                                    $$ = new node("comparison", false, yylineno, ++node_number);
                                    add_child($$, $1);
                                    node *temp_node = new node("KEYWORD_in", true, $2, 0, yylineno, ++node_number);
                                    add_child($$, temp_node);
                                    add_child($$, $3);
                                    
                                    append_tac($$, $1);
                                    append_tac($$, $3);

                                    $$->type_data = BOOL;
                                    quadrup * q = new quadrup();
                                    q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "in");
                                    $$->tac_codes.push_back(q);
                                    $$->tac_str += q->code;

                                    $$->temp_3ac = "t_"+to_string($$->node_number);
                                }
    | expr "not" "in" comparison   {
                                        $$ = new node("comparison", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        node *temp_node = new node("KEYWORD_not", true, $2, 0, yylineno, ++node_number);
                                        add_child($$, temp_node);
                                        node *temp_node2 = new node("KEYWORD_in", true, $3, 0, yylineno, ++node_number);
                                        add_child($$, temp_node2);
                                        add_child($$, $4);

                                        append_tac($$, $1);
                                        append_tac($$, $4);

                                        $$->type_data = BOOL;
                                        quadrup * q = new quadrup();
                                        q->gen_quad_operator($1->temp_3ac, $4->temp_3ac, "t_"+to_string($$->node_number), "not in");
                                        $$->tac_codes.push_back(q);
                                        $$->tac_str += q->code;

                                        $$->temp_3ac = "t_"+to_string($$->node_number);

                                    }
    | expr "is" comparison          {
                                        $$ = new node("comparison", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        node *temp_node = new node("KEYWORD_is", true, $2, 0, yylineno, ++node_number);
                                        add_child($$, temp_node);
                                        add_child($$, $3);
                                        
                                        append_tac($$, $1);
                                        append_tac($$, $3);

                                        $$->type_data = BOOL;
                                        quadrup * q = new quadrup();
                                        q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "is");
                                        $$->tac_codes.push_back(q);
                                        $$->tac_str += q->code;

                                        $$->temp_3ac = "t_"+to_string($$->node_number);
                                    }
| expr "is" "not" comparison        {
                                        $$ = new node("comparison", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        node *temp_node = new node("KEYWORD_is", true, $2, 0, yylineno, ++node_number);
                                        add_child($$, temp_node);
                                        node *temp_node2 = new node("KEYWORD_not", true, $3, 0, yylineno, ++node_number);
                                        add_child($$, temp_node2);
                                        add_child($$, $4);

                                        append_tac($$, $1);
                                        append_tac($$, $4);

                                        $$->type_data = BOOL;
                                        quadrup * q = new quadrup();
                                        q->gen_quad_operator($1->temp_3ac, $4->temp_3ac, "t_"+to_string($$->node_number), "is not");
                                        $$->tac_codes.push_back(q);
                                        $$->tac_str += q->code;
                                          
                                        $$->temp_3ac = "t_"+to_string($$->node_number);
                                    }
| expr                              {
                                        $$ = new node("comparison", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        $$->atom_test = $1->atom_test;
                       
                                        $$ -> type_data = $1 -> type_data;
                                        $$->array_types = $1->array_types;
                                        $$->type_entry = $1->type_entry;
                                        
                                        // quadrup* q = new quadrup();
                                        // q->gen_quad_variable_decl( $1->temp_3ac, "t_"+to_string($$->node_number));
                                        // $$->tac_codes.push_back(q);
                                        // $$->tac_str += q->code;
                                        append_tac($$, $1);

                                        $$->temp_3ac = $1->temp_3ac;
                                    }

;


expr:    
xor_expr "|" expr                  {
                                        $$ = new node("expr", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        node *temp_node = new node("OPERATOR_bitwise_or", true, $2, 0, yylineno, ++node_number);
                                        add_child($$, temp_node);
                                        add_child($$, $3);
                                        
                                        // XXX: Check for error
                                        
                                        $$->type_data = INT;
                                        $$->type_entry = $1->type_entry;
                                        if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Operator | not supported for array "<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1);
                                        }
                                        if(!check_data_type2($1->type_data, $3->type_data)){
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Incompatible types for | "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1); 
                                        }
                                        append_tac($$, $1);
                                        append_tac($$, $3);
                                        quadrup * q = new quadrup();
                                        q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "|");
                                        $$->tac_codes.push_back(q);
                                        $$->tac_str += q->code;
                                        $$->temp_3ac = "t_"+to_string($$->node_number);

                                    }
| xor_expr                      {
                                    $$ = new node("expr", false, yylineno, ++node_number);
                                    add_child($$, $1);
                                    $$->atom_test = $1->atom_test;
                        
                                    $$->type_data = $1->type_data;
                                    $$->array_types = $1->array_types;
                                    $$->type_entry = $1->type_entry;
                                    // quadrup* q = new quadrup();
                                    // q->gen_quad_variable_decl( $1->temp_3ac, "t_"+to_string($$->node_number));
                                    // $$->tac_codes.push_back(q);
                                    // $$->tac_str += q->code;
                                    append_tac($$, $1);
                                    $$->temp_3ac = $1->temp_3ac;
                                }
;

xor_expr:
and_expr "^" xor_expr               {
                                        $$ = new node("xor_expr", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        node *temp_node = new node("OPERATOR_bitwise_xor", true, $2, 0, yylineno, ++node_number);
                                        add_child($$, temp_node);
                                        add_child($$, $3);
        
                                        // XXX: Check for error
                                        $$->type_data = INT;
                                        $$->type_entry = $1->type_entry;
                                        if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Operator ^ not supported for array "<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1);
                                        }
                                        if(!check_data_type2($1->type_data, $3->type_data)){
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Incompatible types for ^ "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1); 
                                        }
                            
                                        append_tac($$, $1);
                                        append_tac($$, $3);
                                        quadrup * q = new quadrup();
                                        q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "^");
                                        $$->tac_codes.push_back(q);
                                        $$->tac_str += q->code;
                                        $$->temp_3ac = "t_"+to_string($$->node_number);
                                    }
| and_expr                          {
                                        $$ = new node("xor_expr", false, yylineno, ++node_number);
                                        add_child($$, $1);

                                        $$->atom_test = $1->atom_test;
                                        $$->type_entry = $1->type_entry;
                                        $$->type_data = $1->type_data;
                                        $$->array_types = $1->array_types;
                                        
                                        // quadrup* q = new quadrup();
                                        // q->gen_quad_variable_decl( $1->temp_3ac, "t_"+to_string($$->node_number));
                                        // $$->tac_codes.push_back(q);
                                        // $$->tac_str += q->code;
                                        append_tac($$, $1);
                                        $$->temp_3ac = $1->temp_3ac;
                                    }
;

and_expr: 
shift_expr                          { 
                                        $$ = new node("and_expr", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        $$->type_data = $1->type_data;
                                        $$->array_types = $1->array_types;
                                        $$->type_entry = $1->type_entry;
                                        // quadrup* q = new quadrup();
                                        // q->gen_quad_variable_decl( $1->temp_3ac, "t_"+to_string($$->node_number));
                                        // $$->tac_codes.push_back(q);
                                        // $$->tac_str += q->code;
                                        append_tac($$, $1);
                                        $$->temp_3ac = $1->temp_3ac;
                                        $$->atom_test = $1->atom_test;

                                    }
| shift_expr "&" and_expr           {
                                        $$ = new node("and_expr", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        node *temp_node = new node("OPERATOR_bitwise_and", true, "&amp;", 0, yylineno, ++node_number);
                                        add_child($$, temp_node);
                                        add_child($$, $3);
                                        $$->type_data = INT;
                                        $$->type_entry = $3->type_entry;
                                        if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Operator & not supported for array "<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1);
                                        }
                                        if(!check_data_type2($1->type_data, $3->type_data)){
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Incompatible types for & "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1); 
                                        }

                                        append_tac($$, $1);
                                        append_tac($$, $3);

                                        quadrup * q = new quadrup();
                                        q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "&");
                                        $$->tac_codes.push_back(q);
                                        $$->tac_str += q->code;
                                        $$->temp_3ac = "t_"+to_string($$->node_number);
                                    }
;

shift_expr: arith_expr              {
                                        $$ = new node("shift_expr", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        $$->atom_test = $1->atom_test;

                                        $$->type_data = $1->type_data;
                                        $$->array_types = $1->array_types;
                                        $$->type_entry = $1->type_entry;
                                        
                                        // quadrup* q = new quadrup();
                                        // q->gen_quad_variable_decl( $1->temp_3ac, "t_"+to_string($$->node_number));
                                        // $$->tac_codes.push_back(q);
                                        // $$->tac_str += q->code;
                                        append_tac($$, $1);
                                        $$->temp_3ac = $1->temp_3ac;
                                    }
| arith_expr "<<" shift_expr       {
                                        $$ = new node("shift_expr", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        node *temp_node = new node("OPERATOR_left_shift", true, "&lt;&lt;", 0, yylineno, ++node_number);
                                        add_child($$, temp_node);
                                        add_child($$, $3);

                                        // XXX: Check for error
                                        $$->type_data = INT;
                                        $$->type_entry = $1->type_entry;
                                        if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Operator << not supported for array "<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1);
                                        }
                                        if(!check_data_type2($1->type_data, $3->type_data)){
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Incompatible types for >> "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1); 
                                        }

                                        append_tac($$, $1);
                                        append_tac($$, $3);
                                        quadrup * q = new quadrup();
                                        q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "<<");
                                        $$->tac_codes.push_back(q);
                                        $$->tac_str += q->code;
                                        $$->temp_3ac = "t_"+to_string($$->node_number);
                                    }
| arith_expr ">>" shift_expr  {
                                    $$ = new node("shift_expr", false, yylineno, ++node_number);
                                    add_child($$, $1);
                                    node *temp_node = new node("OPERATOR_right_shift", true, "&gt;&gt;", 0, yylineno, ++node_number);
                                    add_child($$, temp_node);
                                    add_child($$, $3);

                                    // XXX: Check for error
                                    $$->type_data = INT;
                                    $$->type_entry = $1->type_entry;

                                    if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                        cerr<<"Operator >> not supported for array "<<endl;
                                        cerr<<"************************************************************************"<<endl;
                                        exit(1);
                                    }
                                    
                                    if(!check_data_type2($1->type_data, $3->type_data)){
                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                        cerr<<"Incompatible types for >> "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                        cerr<<"************************************************************************"<<endl;
                                        exit(1);
                                    }

                                    append_tac($$, $1);
                                    append_tac($$, $3);

                                    quadrup * q = new quadrup();
                                    q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), ">>");
                                    $$->tac_codes.push_back(q);
                                    $$->tac_str += q->code;
                                    $$->temp_3ac = "t_"+to_string($$->node_number);

                                }            
;

arith_expr: term                {   $$ = new node("arith_expr", false, yylineno, ++node_number);
                                    add_child($$, $1);
                                    $$->atom_test = $1->atom_test;
                                    
                                    $$->type_entry = $1->type_entry;
                                   
                                    $$->type_data = $1->type_data;
                                    $$->array_types = $1->array_types;
                                    
                                    // quadrup* q = new quadrup();
                                    // q->gen_quad_variable_decl( $1->temp_3ac, "t_"+to_string($$->node_number));
                                    // $$->tac_codes.push_back(q);
                                    // $$->tac_str += q->code;

                                    append_tac($$, $1);

                                    $$->temp_3ac = $1->temp_3ac;
                                }
| arith_expr "+" term           {
                                    $$ = new node("arith_expr", false, yylineno, ++node_number);
                                    add_child($$, $1);
                                    node *temp_node = new node("OPERATOR_add", true, $2, 0, yylineno, ++node_number);
                                    add_child($$, temp_node);
                                    add_child($$, $3);
                                    // XXX : check for error
                                    $$->type_entry = $1->type_entry;
                                    if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                        cerr<<"Operator + not supported for array "<<endl;
                                        cerr<<"************************************************************************"<<endl;
                                        exit(1);
                                    }
                                    $$->type_data = $1->type_data;

                                    if($1->type_data == FLOAT || $3->type_data == FLOAT )$$->type_data = FLOAT;
                                    else $$->type_data = INT;

                                    if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                        cerr<<"Operator + not supported for array "<<endl;
                                        cerr<<"************************************************************************"<<endl;
                                        exit(1);
                                    }
                                    if(!check_data_type3($1->type_data, $3->type_data)){
                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                        cerr<<"Incompatible types for + "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                        cerr<<"************************************************************************"<<endl;
                                        exit(1);
                                    }
                                    
                                    append_tac($$, $1);
                                    append_tac($$, $3);

                                    quadrup * q = new quadrup();
                                    q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "+");
                                    $$->tac_codes.push_back(q);
                                    $$->tac_str += q->code;
                                    $$->temp_3ac = "t_"+to_string($$->node_number);

                                }
| arith_expr "-" term           {
                                    $$ = new node("arith_expr", false, yylineno, ++node_number);
                                    add_child($$, $1);
                                    node *temp_node = new node("OPERATOR_subtract", true, $2, 0, yylineno, ++node_number);
                                    add_child($$, temp_node);
                                    add_child($$, $3);
                                    // XXX : check for error
                                    $$->type_entry = $1->type_entry;
                                    if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                        cerr<<"Operator - not supported for array "<<endl;
                                        cerr<<"************************************************************************"<<endl;
                                        exit(1);
                                    }
                                    $$->type_data = $1->type_data;
                                    
                                    if($1->type_data == FLOAT || $3->type_data == FLOAT ) 
                                        $$->type_data = FLOAT;
                                    else 
                                        $$->type_data = INT;


                                    if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                        cerr<<"Operator - not supported for array "<<endl;
                                        cerr<<"************************************************************************"<<endl;
                                        exit(1);
                                    }
                                    if(!check_data_type3($1->type_data, $3->type_data)){
                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                        cerr<<"Incompatible types for - "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                        cerr<<"************************************************************************"<<endl;
                                        exit(1);
                                    }
                                    
                                    append_tac($$, $1);
                                    append_tac($$, $3);

                                    quadrup * q = new quadrup();
                                    q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "-");
                                    $$->tac_codes.push_back(q);
                                    $$->tac_str += q->code;
                                    $$->temp_3ac = "t_"+to_string($$->node_number);
                                }     
;

term:
factor         { 
                    $$ = new node("term", false, yylineno, ++node_number);
                    add_child($$, $1);

                    $$->type_entry = $1->type_entry;
                    $$->type_data = $1->type_data;
                    $$->array_types = $1->array_types;
                    $$->atom_test = $1->atom_test;

                    append_tac($$, $1);
                    // quadrup* q = new quadrup();
                    // q->gen_quad_variable_decl( $1->temp_3ac, "t_"+to_string($$->node_number));
                    // $$->tac_codes.push_back(q);
                    // $$->tac_str += q->code;
                    $$->temp_3ac = $1->temp_3ac;
                }
| term "*" factor  {
                        $$ = new node("term", false, yylineno, ++node_number);
                        add_child($$, $1);
                        node *temp_node = new node("OPERATOR_multiply", true, $2, 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        add_child($$, $3);

                        // XXX: Check for error
                        $$->type_entry = $3->type_entry;
                        $$->type_data = $1->type_data;
                        if($1->type_data == FLOAT || $3->type_data == FLOAT )$$->type_data = FLOAT;
                        else $$->type_data = INT;
                        
                        if($1->type_entry == ARRAY || $3->type_entry == ARRAY) {
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                            cerr<<"Operator * not supported for array "<<endl;
                            cerr<<"************************************************************************"<<endl;
                            exit(1);
                        }
                        if(!check_data_type3($1->type_data, $3->type_data)){
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                            cerr<<"Incompatible types for * "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                            cerr<<"************************************************************************"<<endl;
                            exit(1);
                        }

                        append_tac($$, $1);
                        append_tac($$, $3);

                        quadrup * q = new quadrup();
                        q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "*");
                        $$->tac_codes.push_back(q);
                        $$->tac_str += q->code;
                        $$->temp_3ac = "t_"+to_string($$->node_number);

                    }
| term "/" factor   {   $$ = new node("term", false, yylineno, ++node_number);
                        add_child($$, $1);
                        node *temp_node = new node("OPERATOR_divide", true, $2, 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        add_child($$, $3);

                        // XXX: Check for error
                        $$->type_entry = $3->type_entry;

                        if($1->type_data == FLOAT || $3->type_data == FLOAT ) 
                            $$->type_data = FLOAT;
                        else 
                            $$->type_data = INT;

                        if($1->type_entry == ARRAY || $3->type_entry == ARRAY) {
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                            cerr<<"Operator %% not supported for array "<<endl;
                            cerr<<"************************************************************************"<<endl;
                            exit(1);
                        }
                        if(!check_data_type3($1->type_data, $3->type_data)){
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                            cerr<<"Incompatible types for / "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                            cerr<<"************************************************************************"<<endl;
                            exit(1);
                        }

                        append_tac($$, $1);
                        append_tac($$, $3);
                        quadrup * q = new quadrup();
                        q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "/");
                        $$->tac_codes.push_back(q);
                        $$->tac_str += q->code;
                        $$->temp_3ac = "t_"+to_string($$->node_number);
                    }
| term "%" factor   {
                        $$ = new node("term", false, yylineno, ++node_number);
                        add_child($$, $1);
                        node *temp_node = new node("OPERATOR_modulo", true, $2, 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        add_child($$, $3);

                        $$->type_entry = $3->type_entry;
                        // XXX: Check for error
                        if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                            cerr<<"Operator %% not supported for array "<<endl;
                            cerr<<"************************************************************************"<<endl;
                            exit(1);
                        }
                        if($1->type_data == FLOAT || $3->type_data == FLOAT )
                            $$->type_data = FLOAT;
                        else 
                            $$->type_data = INT;

                        if(!check_data_type3($1->type_data, $3->type_data)){
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                            cerr<<"Incompatible types for % "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                            cerr<<"************************************************************************"<<endl;
                            exit(1);
                        }

                        append_tac($$, $1);
                        append_tac($$, $3);

                        quadrup * q = new quadrup();
                        q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "%");
                        $$->tac_codes.push_back(q);
                        $$->tac_str += q->code;
                        $$->temp_3ac = "t_"+to_string($$->node_number);
                    }
| term "//" factor  {
                        $$ = new node("term", false, yylineno , ++node_number);
                        add_child($$, $1);
                        node *temp_node = new node("OPERATOR_floor_divide", true, $2, 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        add_child($$, $3);

                        $$->type_entry = $3->type_entry;
                        
                        // XXX: Check for error
                        if($1->type_entry == ARRAY || $3->type_entry == ARRAY){
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                            cerr<<"Operator // not supported for array "<<endl;
                            cerr<<"************************************************************************"<<endl;
                            exit(1);
                        }
                        $$->type_data = INT;
                        if(!check_data_type3($1->type_data, $3->type_data)){
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                            cerr<<"Incompatible types for // "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                            cerr<<"************************************************************************"<<endl;
                            exit(1);
                        }

                        append_tac($$, $1);
                        append_tac($$, $3);
                        quadrup * q = new quadrup();
                        q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "//");
                        $$->tac_codes.push_back(q);
                        $$->tac_str += q->code;
                        $$->temp_3ac = "t_"+to_string($$->node_number);
                        
                    }
;

factor:
"+" factor                { $$ = new node("factor", false, yylineno, ++node_number);
                            node *temp_node = new node("OPERATOR_add", true, $1, 0, yylineno, ++node_number);
                            add_child($$, temp_node);
                            add_child($$, $2);
                            // XXX: Check for error
                            $$ -> type_data = $2 -> type_data;
                            if($$->type_data == STRING || $$->type_data == CLASS_TYPE){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Unary operator + not supported for strings and classes "<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1);
                            }

                            append_tac($$, $2);
                            $$->type_entry = $2->type_entry;
                            if($$->type_entry == ARRAY){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Unary operator + not supported for array "<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1);
                            }
                            string s = $2->temp_3ac;
                            if(s[0]=='t'){
                             quadrup * q = new quadrup();
                            q->gen_quad_operator("", $2->temp_3ac,  "t_"+to_string($$->node_number), "+");
                            $$->tac_codes.push_back(q);
                            $$->tac_str += q->code;
                            $$->temp_3ac = "t_"+to_string($$->node_number);
                            }
                            else{
                                $$->temp_3ac = "+"+s;
                            }
                            
                        }
| "-" factor             {
                            $$ = new node("factor", false, yylineno, ++node_number);
                            node *temp_node = new node("OPERATOR_subtract", true, $1, 0, yylineno, ++node_number);
                            add_child($$, temp_node);
                            add_child($$, $2);
                            // XXX: Check for error
                            $$ -> type_data = $2 -> type_data;
                            if($$->type_data == STRING || $$->type_data == CLASS_TYPE){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Unary operator - not supported for strings or objects "<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1);
                            }
                            append_tac($$, $2);
                            $$->atom_test = $2->atom_test;
                            $$->type_entry = $2->type_entry;
                            if($$->type_entry == ARRAY){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Unary operator - not supported for array "<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1);
                            }
                            string s = $2->temp_3ac;
                            if(s[0]=='t'){
                             quadrup * q = new quadrup();
                            q->gen_quad_operator("", $2->temp_3ac,  "t_"+to_string($$->node_number), "-");
                            $$->tac_codes.push_back(q);
                            $$->tac_str += q->code;
                            $$->temp_3ac = "t_"+to_string($$->node_number);
                            }
                            else{
                                $$->temp_3ac = "-"+s;
                            }
                            
                        }
| "~" factor             {
                            $$ = new node("factor", false, yylineno, ++node_number);
                            node *temp_node = new node("OPERATOR_bitwise_not", true, $1, 0, yylineno, ++node_number);
                            add_child($$, temp_node);
                            add_child($$, $2);
                            // XXX: Check for error
                            $$->type_data = $2->type_data;
                            $$->type_entry = $2->type_entry;
                            if($$->type_entry == ARRAY){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Unary operator ~ not supported for array "<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1);
                            }
                            if($$->type_data == STRING || $$->type_data == CLASS_TYPE){
                                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                cerr<<"Error at line number: "<<yylineno-1<<endl;
                                cerr<<"Unary operator ~ not supported for strings or objects "<<endl;
                                cerr<<"************************************************************************"<<endl;
                                exit(1);
                            }

                            append_tac($$, $2);
                            quadrup * q = new quadrup();
                            q->gen_quad_operator("", $2->temp_3ac,  "t_"+to_string($$->node_number), "~");
                            $$->tac_codes.push_back(q);
                            $$->tac_str += q->code;
                            $$->temp_3ac = "t_"+to_string($$->node_number);
                        }      
| power                  { $$ = new node("factor", false, yylineno, ++node_number);
                            add_child($$, $1);
                            $$->atom_test = $1->atom_test;

                            $$->type_data = $1 -> type_data;
                            $$->type_entry = $1 -> type_entry;
                            $$->array_types = $1->array_types;
                            append_tac($$, $1);
                            $$->temp_3ac = $1->temp_3ac;
                            
                        } 
;

power:
atom_expr                   {  
                                $$ = new node("power", false, yylineno, ++node_number);
                                add_child($$, $1);
                                $$->atom_test = $1->atom_test;

                                $$->array_types = $1->array_types;
                                if($1->atom_name.size()!=0){
                                    if(debug_symbol_table) cout<<"ATOM_NAME : atom name passed to the function is :" <<endl;
                                    for(auto s: $1->atom_name){
                                        if(debug_symbol_table) cout<<s<<" ";
                                    }
                                    if(debug_symbol_table) cout<<endl;
                                    
                                    if($1->atom_name[0] == "len") {
                                        if(debug_symbol_table) cout<<"LEN FUNCTION CALLED"<<endl;
                                        if(debug_symbol_table) cout<<"LEN: "<<entrytype[$1->args[0]->type_entry]<<endl;
                                        if($1->args.size() != 1) {   // only len(a) allowed
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Error: More than or less than 1 arguments for len()"<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1);
                                        }
                                        else if(current_symbol_table.top()->lookup_var($1->args[0]->atom_test->lexeme)!=NULL) {
                                            $$->type_data = INT;
                                            $$->type_entry = LITERAL;
                                            // //maintaining a map of array name and size 
                                            // $$->temp_3ac = to_string(list_map[$1->args[0]->atom_test->lexeme]);
                                            // if(debug_symbol_table) cout<<"LEN: set to "<<$$->temp_3ac<<endl;
                                            $$->temp_3ac = "t_"+to_string($$->node_number);
                                            quadrup* q = new quadrup();

                                            q->gen_quad_variable_lookup_offset($1->args[0]->atom_test->lexeme, "t_"+to_string($$->node_number)+"_len", -8);
                                            $$->tac_codes.push_back(q);
                                            $$->tac_str += q->code;

                                            q = new quadrup();
                                            q->gen_quad_variable_dereference("t_"+to_string($$->node_number)+"_len", $$->temp_3ac);
                                            $$->tac_codes.push_back(q);
                                            $$->tac_str += q->code;
                                            
                                            
                                        }
                                        else {
                                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                                            cerr<<"Error: Undeclared variable"<<endl;
                                            cerr<<"************************************************************************"<<endl;
                                            exit(1);
                                        }
                                        append_tac($$, $1);

                                    }
                                    else{ 
                                        symbol_table_entry* entry = sym_table_lookup($1->atom_name, $1);
                                         
                                        if($1->type_entry == FUNCTION && (entry->name != "print") && (entry->name != "range") && (entry->name != "len") ){
                                            
                                            // REMOVE LATER 
                                            // cerr<<"FUNCTION NAME IS "<<entry->name<<" type data "<<typedata[$1->type_data]<<endl;
                                            $1->type_data = entry->next_table->return_type;
                                            entry->type_data = $1->type_data;
                                        //    cerr<<"FUNCTION NAME IS "<<entry->name<<" type data "<<typedata[$1->type_data]<<endl;
                                        }


                                        get_temp_of_atom_expr($1, $$);
                                        append_tac($$, $1);

                                        string s = $1->temp_3ac;
                                        if(s[0]=='*'){
                                        s = s.substr(1); 
                                        quadrup * q = new quadrup();
                                        q->gen_quad_variable_decl($1->temp_3ac, s + "_" + to_string($$->node_number));
                                        $$->tac_codes.push_back(q);
                                        $$->tac_str += q->code;
                                        $1->temp_3ac = s + "_" + to_string($$->node_number);}

                                        $$->type_entry = $1->type_entry;
                                        $$->type_data = $1->type_data;
                                        $$->temp_3ac = $1->temp_3ac;
                                  
                                       
                                    }
                                }
                                else if($1->atom_name.size()==0){
                                    $$->type_data = $1->type_data;
                                    $$->temp_3ac = $1->temp_3ac;
                                    append_tac($$, $1);

                                }
                                
 
                            }
| atom_expr "**" factor     {
                                $$ = new node("power", false, yylineno, ++node_number);
                                add_child($$, $1);
                                node *temp_node = new node("OPERATOR_power", true, $2, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                add_child($$, $3);
                                $$->atom_test = $1->atom_test;
                                if($1->atom_name.size()!=0){

                                    if(debug_symbol_table) cout<<"ATOM_NAME : atom name passed to the function is :" <<endl;
                                    for(auto s: $1->atom_name){
                                        if(debug_symbol_table) cout<<s<<" ";
                                    }
                                    if(debug_symbol_table)cout<<endl;

                                    symbol_table_entry* entry = sym_table_lookup($1->atom_name, $1);
                                    if(debug_symbol_table) cout<<"LOOK_UP: "<<entry->name<< "CLASS OF ENTRY : "<<entry->present_table->name<<endl;
                                   

                                }
                                $$->type_data = $1->type_data;
                                $$->type_entry = $1->type_entry;
                                
                                append_tac($$, $1);
                                append_tac($$, $3);

                                //xxx entry type implementation
                                quadrup * q = new quadrup();
                                q->gen_quad_operator($1->temp_3ac, $3->temp_3ac, "t_"+to_string($$->node_number), "**");
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                $$->temp_3ac = "t_"+to_string($$->node_number);

                                if(!check_data_type1($1->type_data, $3->type_data)){
                                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                                    cerr<<"Type mismatch between "<<typedata[$1->type_data]<<" and "<<typedata[$3->type_data]<<endl;
                                    cerr<<"************************************************************************"<<endl;
                                    exit(1);
                                }

                            }
;

atom_expr: atom             { 
                                $$ = new node("atom_expr", false, yylineno, ++node_number);
                                add_child($$, $1);

                                if($1->lexeme != "#") { 
                                    ($$->atom_name).push_back($1->lexeme);
                                    if(debug_symbol_table) cout<<"ATOM_NAME : Pushing back "<<$1->lexeme<<endl;
                                }
                                $$->type_data = $1->type_data;
                                $$->type_entry = $1->type_entry;
                                $$->array_types = $1->array_types;

                                $$->temp_3ac = $1->temp_3ac;
                                $$->temp_3ac_2 = $$->temp_3ac;
                                $$->atom_test = $1;
                                append_tac($$, $1);
                            }
| atom_expr trailer         { 
                                $$ = new node("atom_expr", false, yylineno, ++node_number);
                                add_child($$, $1);
                                add_child($$, $2);
                                append_tac($$, $1);
                                append_tac($$, $2);
                                for(string s : $1 -> atom_name){
                                    if(s != "#") $$ -> atom_name.push_back(s);
                                }
                                if($1->lexeme!="#"){ 
                                    ($$->atom_name).push_back($2->lexeme);
                                    if(debug_symbol_table) cout<<"ATOM_NAME : Pushing back "<<$2->lexeme<<endl;
                                }
                                $$->type_data = $1->type_data;
                                $$->type_entry = $2->type_entry;
                                for(auto s: $1->arg_types){
                                    $$->arg_types.push_back(s);
                                }
                                for(auto s: $2->arg_types){
                                    $$->arg_types.push_back(s);
                                }
                                for(auto s: $1->args){
                                    $$->args.push_back(s);
                                }
                                for(auto s: $2->args){
                                    $$->args.push_back(s);
                                }
                                
                                if($2->type_entry == OBJECT){
                                    $$->temp_3ac = $1->temp_3ac + "_" + $2->lexeme;
                                    $$->temp_3ac_2 = $$->temp_3ac;

                                }
                                else {
                                    $$->temp_3ac = $1->temp_3ac;
                                    $$->temp_3ac_2 = $1->temp_3ac;
                                }
                                //think about what to do with 3AC 
                                
                                if($2->multidimensional_array){
                                    if($1->multidimensional_array) { 
                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                        cerr<<"Trying to reference more dimensions than declared in array "<<endl;
                                        cerr<<"************************************************************************"<<endl;
                                        exit(1);
                                    }
                                    $$->multidimensional_array = true;
                                }

                                $$->atom_test = $1->atom_test;
                            }
;


atom:             
"("  ")"                    { 
                                $$ = new node("Atom", false, yylineno, ++node_number);
                                node *temp_node = new node("DELIMITER_open_parenthesis", true, $1, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                temp_node = new node("DELIMITER_close_parenthesis", true, $2, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                
                                $$->lexeme = "#";
                                $$->type_data = NONE;
                                $$->type_entry = VARIABLE;
                            }
| "(" test ")"              {
                                $$ = new node("Atom", false, yylineno, ++node_number);
                                node *temp_node = new node("DELIMITER_open_square_bracket", true, $1, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                add_child($$, $2);
                                temp_node = new node("DELIMITER_close_square_bracket", true, $3, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                
                                $$->lexeme = "#";
                                $$->type_data = $2->type_data;
                                $$->type_entry = VARIABLE;
                                
                                append_tac($$, $2);
                                
                                $$->temp_3ac = $2->temp_3ac;
                                // quadrup* q = new quadrup();
                                // q->gen_quad_variable_decl($2->temp_3ac, "t_"+to_string($$->node_number));
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                            }
| "["  "]"                  { 
                                $$ = new node("Atom", false, yylineno, ++node_number);
                                node *temp_node = new node("DELIMITER_open_square_bracket", true, $1, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                temp_node = new node("DELIMITER_close_square_bracket", true, $2, 0, yylineno, ++node_number);
                                add_child($$, temp_node);

                                $$->lexeme = "#";
                                $$->type_entry = ARRAY;
                                $$->type_data = NONE;

                                // Quadruple
                                // TODO: Generate tac for arrays
                            }
| "[" testlist "]"          {
                                
                                $$ = new node("Atom", false, yylineno, ++node_number);
                                node *temp_node = new node("DELIMITER_open_square_bracket", true, $1, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                add_child($$, $2);
                                temp_node = new node("DELIMITER_close_square_bracket", true, $3, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                
                                $$->lexeme = "#";
                                $$->type_entry = ARRAY;
                                $$->type_data = $2->type_data;
                                $$->array_types = $2->list_types;
                                
                                //check that the type of all array elements is same
                                if(debug_symbol_table) cout<<"TYPE OF ELEMENTS IN ARRAY ARE :"<<endl;
                                for(auto s : $$->array_types){
                                    if(debug_symbol_table) cout<<s<<" ";
                                    if( !check_data_type($$->type_data , s)){
                                        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                                        cerr<<"Error at line number: "<<yylineno-1<<endl;
                                        cerr<<"Type mismatch in list declaration and values "<<endl;
                                        cerr<<"************************************************************************"<<endl;
                                        exit(1);
                                    }
                            
                                }
                                if(debug_symbol_table) cout<<endl;

                                append_tac($$, $2);
                                // Quadruple
                                // TODO: Generate tac for arrays
                                //allocate this much size for array
                                quadrup* q = new quadrup();
                                uint64_t size = $2->list_types.size()*8;
                                q->gen_quad_push_param(to_string(size + 8));
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;

                                q = new quadrup();
                                q->gen_quad_call_func("allocmem");
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                 
                                q = new quadrup();
                                q->gen_func_get_retval( "t_"+to_string($$->node_number));
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                
                                // store length
                                 q = new quadrup();

                                    q->gen_quad_variable_lookup_offset("t_"+to_string($$->node_number), "t_"+to_string($$->node_number)+"_"+to_string(0), 0);
                                    $$->tac_codes.push_back(q);
                                    $$->tac_str += q->code;

                                    q = new quadrup();
                                    q->gen_quad_variable_dereference_left(to_string($$->array_types.size()), "t_"+to_string($$->node_number)+"_"+to_string(0));
                                    $$->tac_codes.push_back(q);
                                    $$->tac_str += q->code;
                                // memory m store array ki value kardi 
                                for(int i = 0; i < $$->array_types.size(); i++){
                                    
                                    quadrup* q = new quadrup();

                                    q->gen_quad_variable_lookup_offset("t_"+to_string($$->node_number), "t_"+to_string($$->node_number)+"_"+to_string(i+1), 8*(i+1));
                                    $$->tac_codes.push_back(q);
                                    $$->tac_str += q->code;

                                    q = new quadrup();
                                    q->gen_quad_variable_dereference_left($2->list[i]->temp_3ac, "t_"+to_string($$->node_number)+"_"+to_string(i+1));
                                    $$->tac_codes.push_back(q);
                                    $$->tac_str += q->code;
                                }

                                q = new quadrup();
                                q->gen_quad_operator("t_"+to_string($$->node_number), "8", "t_"+to_string($$->node_number), "+");
                                $$->tac_codes.push_back(q);
                                $$->tac_str += q->code;
                                $$->temp_3ac = "t_"+to_string($$->node_number);

                            }
| NAME                      {
                                $$ = new node("Atom", false, yylineno, ++node_number);
                                node *temp_node = new node("NAME", true, $1, 0, yylineno, ++node_number);
                                add_child($$, temp_node);

                                $$->lexeme = $1;
                                $$->is_name = true;
                                $$->type_data = NONE;
                                $$->type_entry = VARIABLE;

                                $$->exp_str_val = $1; 
                                $$->temp_3ac = $1;
                                // quadrup* q = new quadrup();
                                // q->gen_quad_variable_decl($1, "t_"+to_string($$->node_number));
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;

                            }
| LITERAL_integer           {
                                $$ = new node("Atom", false, yylineno, ++node_number);
                                node *temp_node = new node("LITERAL_integer", true, $1, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                 
                                $$->lexeme = "#";

                                $$->type_data = INT;
                                $$->type_entry = LITERAL;
                                $$->exp_int_val = atoi($1);
                                // quadrup* q = new quadrup();
                                // q->gen_quad_variable_decl($1, "t_"+to_string($$->node_number));
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                $$->temp_3ac = $1;
                            }
| LITERAL_floatingpoint     {
                                $$ = new node("Atom", false, yylineno, ++node_number);
                                node *temp_node = new node("LITERAL_floatingpoint", true, $1, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                $$->lexeme = "#";

                                $$->type_data = FLOAT;
                                $$->type_entry = LITERAL;

                                $$->exp_float_val = atof($1);
                                // quadrup* q = new quadrup();
                                // q->gen_quad_variable_decl($1, "t_"+to_string($$->node_number));
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                $$->temp_3ac = $1;
                            }
/* | LITERAL_imag              {
                                $$ = new node("Atom", false, yylineno);
                                node *temp_node = new node("LITERAL_imag", true, $1, 0, yylineno);
                                add_child($$, temp_node);
                                $$->lexeme = "#";

                               //IMAGINARY KA KYA KARNA HAI
                            } */
| "True"                    {
                                $$ = new node("Atom", false, yylineno, ++node_number);
                                node *temp_node = new node("KEYWORD_true", true, $1, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                $$->lexeme = "#";
                                $$->type_data = BOOL;
                                $$->type_entry = LITERAL;
                                $$->exp_bool_val = 1;
                                // quadrup* q = new quadrup();
                                // q->gen_quad_variable_decl("1", "t_"+to_string($$->node_number));
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                $$->temp_3ac = "1";
                            }
| "False"                   {
                                $$ = new node("Atom", false, yylineno, ++node_number);
                                node *temp_node = new node("KEYWORD_false", true, $1, 0, yylineno, ++node_number);
                                add_child($$, temp_node);
                                $$->lexeme = "#";
                                $$->type_data = BOOL;
                                $$->type_entry = LITERAL;
                                $$->exp_bool_val = 0;
                                // quadrup* q = new quadrup();
                                // q->gen_quad_variable_decl("0", "t_"+to_string($$->node_number));
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                $$->temp_3ac = "0";
                            }
| string_plus               {
                                $$ = new node("Atom", false, yylineno, ++node_number);
                                add_child($$, $1);
                                $$->lexeme = "#";
                                $$->type_data = STRING;
                                $$->type_entry = LITERAL;
                                $$->exp_str_val = $1->exp_str_val;
                                // quadrup* q = new quadrup();
                                // q->gen_quad_variable_decl($$->exp_str_val, "t_"+to_string($$->node_number));
                                // $$->tac_codes.push_back(q);
                                // $$->tac_str += q->code;
                                $$->temp_3ac = $1->exp_str_val;
                            }                               
                            
;            
            
string_plus: LITERAL_string         {
                                        $$ = new node("Multiple_strings", false, yylineno, ++node_number);
                                        node *temp_node = new node("LITERAL_string", true, $1, 0, yylineno, ++node_number);
                                        add_child($$, temp_node);
                                        $$->exp_str_val = $1;
                                    }          
| string_plus LITERAL_string        {
                                        $$ = new node("Multiple_strings", false, yylineno, ++node_number);
                                        add_child($$, $1);
                                        node *temp_node = new node("LITERAL_string", true, $2, 0, yylineno, ++node_number);
                                        add_child($$, temp_node);
                                        $$->exp_str_val = $1->exp_str_val + $2;
                                    }                                  
;

trailer:  "(" ")"   { 
                        $$ = new node("trailer", false, yylineno, ++node_number);
                        node *temp_node = new node("DELIMITER_open_parenthesis", true, $1, 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        temp_node = new node("DELIMITER_close_parenthesis", true, $2, 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        
                        $$->lexeme = "()";
                        $$->type_entry = FUNCTION;
                    }
| "(" testlist ")"  {  
                        $$ = new node("trailer", false, yylineno, ++node_number);
                        node *temp_node = new node("DELIMITER_open_parenthesis", true, $1, 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        add_child($$, $2);
                        temp_node = new node("DELIMITER_close_parenthesis", true, $3, 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        
                        append_tac($$, $2);
                        $$->lexeme = "()";
                        $$->type_entry = FUNCTION;
                        $$->arg_types = $2->list_types;
                        $$->args = $2->list;
                    }
| "[" test "]"      {
                        $$ = new node("trailer", false, yylineno, ++node_number);
                        node *temp_node = new node("DELIMITER_open_square_bracket", true, $1, 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        add_child($$, $2);
                        temp_node = new node("DELIMITER_close_square_bracket", true, $3, 0, yylineno, ++node_number);
                        add_child($$, temp_node);

                        $$->lexeme = "[]";
                        $$->type_entry = VARIABLE;
                        //test can only be of type int and bool 
                        if($2->type_data != INT && $2->type_data != BOOL){
                            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                            cerr<<"Error at line number: "<<yylineno-1<<endl;
                            cerr<<"Indexing variable must be an integer "<<endl;
                            cerr<<"************************************************************************"<<endl;
                            exit(1);
                        }
                        $$->multidimensional_array = true;
                        append_tac($$, $2); // XXX
                        // Quadruple
                        $$->args.push_back($2);
                        $$->arg_types.push_back($2->type_data);
                        $$->tac_str += $2->tac_str;
                    }
| "." NAME          {
                        $$ = new node("trailer", false, yylineno, ++node_number);
                        node *temp_node = new node("DELIMITER_dot", true, $1, 0, yylineno, ++node_number);
                        add_child($$, temp_node);
                        temp_node = new node("NAME", true, $2, 0, yylineno, ++node_number);
                        add_child($$, temp_node);      

                        $$->lexeme = $2;
                        $$->type_entry = OBJECT;  // XXX: Check for error

                    }  
                          
;



testlist: test  {   
                    $$ = new node("testlist", false, yylineno, ++node_number);
                    add_child($$, $1);
                    
                    // symbol_table_entry* temp_entry = sym_table_lookup()
                    append_tac($$, $1);

                    $$->type_data = $1->type_data;
                    $$->list_types.push_back($1->type_data);
                    $$->list.push_back($1);
                }
| test ","      {   
                    $$ = new node("testlist", false, yylineno, ++node_number);
                    add_child($$, $1);
                    node * temp_node = new node("DELIMITER_comma", true, $2, 0, yylineno, ++node_number);
                    add_child($$, temp_node);

                    append_tac($$, $1);

                    $$->type_data = $1->type_data;
                    $$->list_types.push_back($1->type_data);
                    $$->list.push_back($1);
                }
| test "," testlist     {
                            $$ = new node("testlist", false, yylineno, ++node_number);
                            add_child($$, $1);
                            node * temp_node = new node("DELIMITER_comma", true, $2, 0, yylineno, ++node_number);
                            add_child($$, temp_node);
                            add_child($$, $3);

                            append_tac($$, $1);
                            append_tac($$, $3);

                            $$->type_data = $1->type_data;
                            $$->list_types.push_back($1->type_data);
                            $$->list.push_back($1);
                            for(auto list_type: $3->list_types) {
                                $$->list_types.push_back(list_type);
                            }
                            for(auto list_item: $3->list) {
                                $$->list.push_back(list_item);
                            }
                        }

;



classdef: "class" NAME ":"
            {
                symbol_table_generic* sym_temp = new symbol_table_generic($2, "C", yylineno);
                symbol_table_generic* parent = current_symbol_table.top();
                symbol_table_entry *entry = new symbol_table_entry($2, CLASS, parent, sym_temp , yylineno);
                //xxx set entry type and data type of the entry 
                entry->type_entry = CLASS;
                parent->add_entry(entry);
                if(debug_symbol_table)cout<<"ADD_ENTRY : (8) adding entry :"<<entry->name<<" IN symbol table : "<<parent->name<<endl;
                sym_temp->parent_table = parent;
                current_symbol_table.push(sym_temp);
                class_table[$2] = sym_temp;
                if(debug_symbol_table)cout<<" STACK : TOP OF CURRENT SYMBOL TABLE STACK WAS : "<<parent->name<<" NOW PUSHED :"<<sym_temp->name<<endl;

            }
            suite                                             
            {                                                                 
                $$ = new node("Class_definition", false, yylineno, ++node_number);
                node *temp_node = new node("KEYWORD_class", true, $1, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                temp_node = new node("NAME", true, $2, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                temp_node = new node("DELIMITER_colon", true, $3, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                add_child($$, $5);
                append_tac($$, $5);
                current_symbol_table.top()->scope_end_lineno = yylineno;
                current_symbol_table.pop();

            }          
| "class" NAME "(" NAME ")" ":"
            {

                symbol_table_generic* sym_temp = new symbol_table_generic($2, "C", yylineno);
                symbol_table_generic* parent = current_symbol_table.top();
                symbol_table_entry *entry = new symbol_table_entry($2, CLASS , parent, sym_temp , yylineno);
                //xxx set entry type and data type of the entry 

                entry->type_entry = CLASS;

                parent->add_entry(entry);
                if(debug_symbol_table)cout<<"ADD_ENTRY : (9) adding entry :"<<entry->name<<" IN symbol table : "<<parent->name<<endl;
                sym_temp->parent_table = parent;
                current_symbol_table.push(sym_temp);
                class_table[$2] = sym_temp;

                string inherited_class_name = $4;

                sym_temp->parent_class = class_table[inherited_class_name];
                sym_temp->size = sym_temp->parent_class->size;
                if(debug_symbol_table) cout<<"STACK : TOP OF CURRENT SYMBOL TABLE STACK WAS : "<<parent->name<<" NOW PUSHED :"<<sym_temp->name<<endl;
            }
            
            suite    
            {
                $$ = new node("Class_definition", false, yylineno, ++node_number);
                node *temp_node = new node("KEYWORD_class", true, $1, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                temp_node = new node("NAME", true, $2, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                temp_node = new node("DELIMITER_open_parenthesis", true, $3, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                temp_node = new node("NAME", true, $4, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                temp_node = new node("DELIMITER_close_parenthesis", true, $5, 0, yylineno, ++node_number);
                add_child($$, temp_node);
                temp_node = new node("DELIMITER_colon", true, $6, 0, yylineno, ++node_number);
                add_child($$, temp_node);

                add_child($$, $8);
                append_tac($$, $8);
                
                current_symbol_table.top()->scope_end_lineno = yylineno;
                current_symbol_table.pop();
            }
;

%%

int get_offset(vector<string> &compound_name, node *temp) {
    int offset = 0;
    if(debug_symbol_table)cout << "GET_OFFSET : Inside offset Lookup : " << endl;
    if(debug_symbol_table)cout << "GET_OFFSET : COMPOUND NAME SIZE : "<<compound_name.size() << endl;
    for(string s : compound_name){
        if(debug_symbol_table)cout << s << " ";
    }
    if(debug_symbol_table)cout<<endl;
    symbol_table_entry *cur_entry = NULL;
    if(compound_name.size() == 0) {  // Wrong input
        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
        cerr<<"Error at line number: "<<yylineno-1<<endl;
        cerr<<"Error: Unknown error"<<endl;
        cerr<<"************************************************************************"<<endl;
        exit(1);
        return -1;
    }
    if(compound_name.size() == 1) {  // Single variable 
        if(debug_symbol_table)cout<<" GET_OFFSET : Looking up single variable"<<endl;
        cur_entry = current_symbol_table.top()->lookup_var(compound_name[0]);
        if(cur_entry==NULL){
            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
            cerr<<"Error at line number: "<<yylineno-1<<endl;
            cerr<<"Error: Undeclared variable"<<endl;
            cerr<<"************************************************************************"<<endl;
            exit(1);
        }
        else{
            if(debug_symbol_table) cout<<"GET_OFFSET : curr_entry name from offset finding of "<<compound_name[0]<<" is "<<cur_entry->name<<endl;
            if(debug_symbol_table) cout<<"GET OFFSET : NOW type_data "<<temp->type_data<<" PREVIOUS  type_data "<<cur_entry->type_data<<endl;

            temp->type_data = cur_entry->type_data; 
            temp->type_entry = cur_entry->type_entry;

        }   
        if(debug_symbol_table) cout<<" GET_OFFSET : Returning -1 for single variable"<<endl;
        /* exit(1); */
        return -1;
    }
    symbol_table_generic *sym_table = current_symbol_table.top();

    for(int i = 0; i < compound_name.size(); i++) {

        if(debug_symbol_table) cout<<" GET_OFFSET : Loop iteration "<<i<<endl;

        if(i == compound_name.size() - 1) {
            if(debug_symbol_table) cout<<" GET_OFFSET : LAST name is  :"<<compound_name[i]<<endl;
            cur_entry = sym_table->lookup_var(compound_name[i]);
            if(cur_entry == NULL){ 
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<yylineno-1<<endl;
                cerr<<"Error: Undeclared variable"<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
            }
            offset += cur_entry->offset;
            break;
        }
        if(compound_name[i+1] == "[]") { // Array
            if(debug_symbol_table) cout<<"GET_OFFSET : Array lookup"<<endl;

            cur_entry = sym_table->lookup_array(compound_name[i]);
            if(cur_entry == NULL) {
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<yylineno-1<<endl;
                cerr<<"Error: Undeclared variable"<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
                return -1;
            }
            i++;
        } 
        else if (compound_name[i+1] == "()") { // Function
            if(debug_symbol_table) cout<<" GET_OFFSET : Function lookup"<<endl;
            cur_entry = sym_table->lookup_func(compound_name[i], temp->arg_types);
            if(debug_symbol_table) cout<<" GET_OFFSET : INSIDE FUNCTION LOOKUP THE TEMP ARGUMENTS PASSED ARE : ";
            //xxx temp_arg_types is empty implement and check in function lookup 
            for(auto s : temp->arg_types){
               if(debug_symbol_table) cout<<s<<" ";
            }
            if(debug_symbol_table) cout<<endl;

            if(cur_entry == NULL) {
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<yylineno-1<<endl;
                cerr<<"Error: Undeclared function"<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
                return -1;
            }
            i++;
        } else {  // Class object
            if(debug_symbol_table) cout<<" GET_OFFSET : Class object lookup"<<endl;
            if(compound_name[i] == "self") {
                sym_table = sym_table->parent_table;
                if(sym_table == NULL) {
                    cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                    cerr<<"Error at line number: "<<yylineno-1<<endl;
                    cerr<<"Error: Invalid usage of self"<<endl;
                    cerr<<"************************************************************************"<<endl;
                    exit(1);
                }
                continue;
            }
            cur_entry = sym_table->lookup_obj(compound_name[i]);
    
            if(cur_entry == NULL) {
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<yylineno-1<<endl;
                cerr<<"Error: Undeclared variable"<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
                return -1;
            }
            if(debug_symbol_table) cout<<" GET_OFFSET : Object entry : "<<cur_entry->name<<" class_name : "<<cur_entry->class_name<<endl;

            if(class_table.find(cur_entry->class_name) == class_table.end()) {
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<yylineno-1<<endl;
                cerr<<"Error: Undeclared variable"<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
                return -1;
            }
            sym_table = class_table[cur_entry->class_name];  // Wrong input
            if(sym_table == NULL) {
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<yylineno-1<<endl;
                cerr<<"Error: Undeclared variable"<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
                return -1;
            }
            if(debug_symbol_table) cout<<"GET_OFFSET : SYM TABLE TO CLASS FOUND NAME : "<<sym_table->name<<endl; 

            
        }
        offset += cur_entry->offset;
    }

    if(cur_entry==NULL)
    {   
        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
        cerr<<"Error at line number: "<<yylineno-1<<endl;
        cerr<<"Error: Undeclared variable"<<endl;
        cerr<<"************************************************************************"<<endl;
        exit(1);
        return -1;
    }
    else{
        if(debug_symbol_table) cout<<"cur_entry name "<<cur_entry->name<<"temp : "<<temp<<endl;
        if(debug_symbol_table) cout<<"PREVIOUS type_data "<<typedata[temp->type_data]<<" NOW type_data"<<typedata[cur_entry->type_data]<<endl;
        if(debug_symbol_table) cout<<"PREVIOUS type_entry "<<entrytype[temp->type_entry]<<" NOW type_entry"<<entrytype[cur_entry->type_entry]<<endl;
        
       if(compound_name.back() == "[]") {   // not actually an array, but indexing an array - type is VARIABLE
            temp->type_data = cur_entry->type_data;
            temp->type_entry = VARIABLE; 
        } else {
            temp->type_data = cur_entry->type_data;
            temp->type_entry = cur_entry->type_entry; 
        
        }

    }
    if(debug_symbol_table)  cout<<"GET_OFFSET : RETURNING OFFSET : "<<offset<<endl;
    return offset;
    
}


symbol_table_entry *sym_table_lookup(vector<string> &compound_name, node *temp) {

    if(debug_symbol_table)cout << "SYM_TABLE_LOOKUP : Inside sym_table_Lookup : " << endl;
    if(debug_symbol_table)cout << compound_name.size() << endl;
    for(string s : compound_name){
        if(debug_symbol_table)cout << s << " ";
    }
    if(debug_symbol_table) cout<<endl;
    symbol_table_entry *cur_entry = NULL;
    if(compound_name.size() == 0) {  // Wrong input
        if(debug_symbol_table) cout<<" SYM_TABLE_LOOKUP : Wrong input"<<endl;
        exit(1);
        return NULL;
    }

    if(compound_name.size() == 1) {  // Single variable */
        if(debug_symbol_table)cout<<" SYM_TABLE_LOOKUP : Looking up single variable"<<endl;
        cur_entry = current_symbol_table.top()->lookup_var(compound_name[0]);
        if(cur_entry==NULL){
            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
            cerr<<"Error at line number: "<<yylineno-1<<endl;
            cerr<<"Error: Undeclared variable"<<endl;
            cerr<<"************************************************************************"<<endl;
            exit(1);
            return  NULL;
        }
        else{
            if(debug_symbol_table) cout<<"curr_entry name "<<cur_entry->name<<endl;
            if(debug_symbol_table) cout<<"PREVIOUS type_data "<<typedata[temp->type_data]<<" NOW type_data"<<typedata[cur_entry->type_data]<<endl;
            if(debug_symbol_table) cout<<"PREVIOUS type_entry "<<entrytype[temp->type_entry]<<" NOW type_entry"<<entrytype[cur_entry->type_entry]<<endl;

            temp->type_data = cur_entry->type_data;
            temp->type_entry = cur_entry->type_entry; 
        }
        return cur_entry;
    }
    symbol_table_generic *sym_table = current_symbol_table.top();
    if(debug_symbol_table)  cout<<"SYM_TABLE_LOOKUP CURRENT SYMBOL TABLE IS "<<current_symbol_table.top()->name<<endl;
    for(int i = 0; i < compound_name.size(); i++) {

        if(debug_symbol_table) cout<<" SYM_TABLE_LOOKUP : Loop iteration "<<i<<endl;
        if(i == compound_name.size() - 1) {
            if(debug_symbol_table) cout<<" SYM_TABLE_LOOKUP : LAST name is  :"<<compound_name[i]<<endl;
            cur_entry = sym_table->lookup_var(compound_name[i]);
            break;
        }
        if(compound_name[i+1] == "[]") { 

            if(debug_symbol_table) cout<<"SYM_TABLE_LOOKUP : Array lookup"<<endl;

            cur_entry = sym_table->lookup_array(compound_name[i]);

            if(cur_entry == NULL) {
                if(debug_symbol_table) cout<<" SYM_TABLE_LOOKUP : LOOKUP OF ARRAY RETURNED NULL"<<endl;
                exit(1);
                return NULL;
            }
            i++;
        } else if (compound_name[i+1] == "()") { // Function
        
            if(debug_symbol_table) cout<<" SYM_TABLE_LOOKUP : Function lookup"<<endl;

            cur_entry = sym_table->lookup_func(compound_name[i], temp->arg_types);
            /* cout<<cur_entry->name<<" : "<<cur_entry->present_table->name<<endl; */
            if(debug_symbol_table) cout<<" SYM_TABLE_LOOKUP : INSIDE FUNCTION LOOKUP THE TEMP ARGUMENTS PASSED ARE : ";
            //xxx temp_arg_types is empty implement and check in function lookup 
            for(auto s : temp->arg_types){
               if(debug_symbol_table) cout<<s<<" ";
            }
            if(debug_symbol_table) cout<<endl;

            if(cur_entry == NULL) {
                if(debug_symbol_table) cout<<"SYM_TABLE_LOOKUP : LOOKUP OF FUNCTION RETURNED NULL"<<endl;
                exit(1);
                return NULL;
            }
            i++;
        } else {  // Class object
            if(debug_symbol_table) cout<<" SYM_TABLE_LOOKUP : Class object lookup"<<endl;

            if(compound_name[i] == "self") {
                continue;
            }
            cur_entry = sym_table->lookup_obj(compound_name[i]);

            if(cur_entry == NULL) {
                if(debug_symbol_table) cout<<"SYM_TABLE_LOOKUP : LOOKUP OF OBJECT RETURNED NULL"<<endl;
                exit(1);
                return NULL;
            }

            if(debug_symbol_table) cout<<" SYM_TABLE_LOOKUP : Object entry : "<<cur_entry->name<<" class_name : "<<cur_entry->class_name<<endl;

            if(class_table.find(cur_entry->class_name) == class_table.end()) {
                if(debug_symbol_table) cout<<" SYM_TABLE_LOOKUP : Object entry class name not found"<<endl;
                exit(1);
                return NULL;
            }

            sym_table = class_table[cur_entry->class_name];  // Wrong input
            if(debug_symbol_table) cout<<"SYM_TABLE_LOOKUP : SYM TABLE TO CLASS FOUND NAME : "<<cur_entry->name<<endl; 
            if(sym_table == NULL) {
                if(debug_symbol_table) cout<<" SYM_TABLE_LOOKUP : ENTRY NOT FOUND IN CLASS TABLE CORRESPONDING TO THE NAME "<<endl;
                exit(1);
                return NULL;
            }
            /* i++; */
        }
    }
        
    if(cur_entry == NULL) {
        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
        cerr<<"Error at line number: "<<yylineno-1<<endl;
        cerr<<"Error: Undeclared variable"<<endl;
        cerr<<"************************************************************************"<<endl;
        exit(1);
    }
    else{
        if(debug_symbol_table) cout<<"cur_entry name "<<cur_entry->name<<" temp : "<<temp<<endl;
        if(debug_symbol_table) cout<<"PREVIOUS type_data "<<typedata[temp->type_data]<<" NOW type_data"<<typedata[cur_entry->type_data]<<endl;
        if(debug_symbol_table) cout<<"PREVIOUS type_entry "<<entrytype[temp->type_entry]<<" NOW type_entry"<<entrytype[cur_entry->type_entry]<<endl;
        if(compound_name.back() == "[]") {   // not actually an array, but indexing an array - type is VARIABLE
            temp->type_data = cur_entry->type_data;
            temp->type_entry = VARIABLE; 
        } else {
            temp->type_data = cur_entry->type_data;
            temp->type_entry = cur_entry->type_entry; 
        
        }
    }
    return cur_entry;
    
}

void add_child(node *parent, node *child) {
    if(child->is_empty == true) {          // Do not add any empty expressions to the parse tree -- unnecessary clutter
        return;
    }
    parent->children.push_back(child);
    child->parent = parent;
    parent->num_child++;
}
 
string get_mangled_name(symbol_table_entry *entry) {

    //YYY mangled name in case of inheritance,
    if(debug_symbol_table) cout<<"GET_MANGLED_NAME : ENTRY NAME IS "<<entry->name<<"PARENT SYMBOL TABLE NAME IS "<<entry->present_table->name<<endl;
    if(entry->is_init){
            if(debug_symbol_table) cout<<"WWWWWWWWWWWWWWWWWWWWW"<<entry->name + "@" + entry->name + "@"<<endl;
            return entry->name + "@" + entry->name + "@";

    }
    if(entry->present_table->parent_table == NULL){
        
        return entry->name;    
    }
    string mangled_name = "";
    stack<string> mangling_stack;
    mangling_stack.push(entry->name);
    symbol_table_generic *table = entry->present_table;

    while(table->parent_table != NULL) {
        mangling_stack.push(table->name);
        table = table->parent_table;
    }
    while(!mangling_stack.empty()) {
        mangled_name += mangling_stack.top();
        mangled_name += "@";
        mangling_stack.pop();
    }
    return mangled_name;
}


void get_temp_of_atom_expr(node *atom_expr, node *parent) {
    // Lookup offset of variable and generate quadruples
    if(atom_expr->atom_name.size() == 1) {
        return;
    }
    if(atom_expr->temp_3ac=="")atom_expr->temp_3ac = "t_" + to_string(parent->node_number);

    symbol_table_entry *entry = sym_table_lookup(atom_expr->atom_name, atom_expr);
    if(debug_symbol_table) cout<<"NAME OF ENTRY IS "<<entry->name<<endl;
    if(debug_symbol_table) cout<<"PRESENT TABLE OF THE ENTRY IS "<<entry->present_table->name<<endl;
    if(debug_symbol_table) cout<<"Inside get_temp_of_atom_expr    entry is : "<<entrytype[entry->type_entry]<<endl;

    int offset = get_offset(atom_expr->atom_name, atom_expr);
    if(debug_symbol_table) cout<<"GET_TEMP: offset is "<< offset<<endl;
    if(offset == -1 && atom_expr->atom_name.size() > 1) {    // Offset is not found, and not a local variable
        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
        cerr<<"Error at line number: "<<yylineno-1<<endl;
        cerr<<"Error: Undeclared variable"<<endl;
        cerr<<"************************************************************************"<<endl;
        exit(1);
    }
    string lastname = atom_expr->atom_name[atom_expr->atom_name.size()-1];
    if(debug_symbol_table) cout<<"INSIDE GET TEMP OF ATOM EXPR : LAST NAME IS : "<<lastname<<" TYPE OF ENTRY IS "<<entrytype[entry->type_entry]<<endl;
    if((entry->type_entry == VARIABLE) || (entry->type_entry == ARRAY && lastname=="[]")) {
        if(atom_expr->atom_name.size() > 1) {
            
            string base_class_name = atom_expr->atom_name[0];
            symbol_table_entry *base_class_entry = current_symbol_table.top()->lookup_array(base_class_name);
            string base_class_temp = "";
            if(base_class_entry == NULL && base_class_name != "self") {
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<yylineno-1<<endl;
                cerr<<"Error: Undeclared variable"<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
            }
            else if(base_class_name == "self") {
                // Find object base class pointer
                base_class_temp = "self";
                atom_expr->temp_3ac = base_class_temp;
            } else {
                // Find object base class pointer
                base_class_temp = base_class_entry->base_ptr_3ac;    // IMPLEMENT @Apoorva
                atom_expr->temp_3ac = base_class_temp;
            }

            if((entry->type_entry == ARRAY && lastname=="[]")) {   // looking up an array index
                if(debug_symbol_table)cout<<" last name is square "<<endl;
                string offs ="0";
                if(lastname=="[]"){   // lookup the index value
                    offs = (atom_expr->args[atom_expr->args.size()-1]->temp_3ac);
                    if(debug_symbol_table) cout<<"GET_TEMP : OFFS IS "<<offs<<endl;
                }
                
                quadrup* q = new quadrup();
                q->gen_quad_operator("0", offs, atom_expr->temp_3ac+"_1", "+");
                /* parent->tac_codes.push_back(q); */
                atom_expr->tac_codes.push_back(q);
                if(debug_symbol_table) cout<<"SPECIAL TAC GENERATED : "<<q->code<<endl;
                /* parent->tac_str += q->code; */
                atom_expr->tac_str += q->code;
                
                q = new quadrup();
                q->gen_quad_operator(atom_expr->temp_3ac+"_1", "8", atom_expr->temp_3ac+"_1", "*");
                /* parent->tac_codes.push_back(q); */
                atom_expr->tac_codes.push_back(q);

                /* parent->tac_str += q->code;  */
                atom_expr->tac_str += q->code;

                q = new quadrup();
                q->gen_quad_operator(atom_expr->temp_3ac+"_1", to_string(offset), atom_expr->temp_3ac+"_1", "+");
                /* parent->tac_codes.push_back(q); */
                atom_expr->tac_codes.push_back(q);

                if(debug_symbol_table) cout<<"SPECIAL TAC GENERATED : "<<q->code<<endl;
                /* parent->tac_str += q->code; */
                atom_expr->tac_str += q->code;
                
                
            } else {                                                // looking up a variable
                quadrup* q = new quadrup();
                q->gen_quad_operator("0", to_string(offset), atom_expr->temp_3ac+"_1", "+");
                /* parent->tac_codes.push_back(q); */
                atom_expr->tac_codes.push_back(q);

                if(debug_symbol_table) cout<<"SPECIAL TAC GENERATED : "<<q->code<<endl;
                /* parent->tac_str += q->code; */
                atom_expr->tac_str += q->code;
            }

            quadrup *q = new quadrup();
            q->gen_quad_variable_lookup_offset(atom_expr->temp_3ac, atom_expr->temp_3ac + "_3",  atom_expr->temp_3ac+"_1");
            /* parent->tac_codes.push_back(q); */
            atom_expr->tac_codes.push_back(q);

            /* parent->tac_str += q->code; */
            atom_expr->tac_str += q->code;
    
            if(entry->type_entry == ARRAY && lastname=="[]"){
                atom_expr->temp_3ac = "*" + atom_expr->temp_3ac+"_3";
                if(debug_symbol_table)cout<<" ARRAY DEREFERENCE "<<entry->name<<" TEMP 3AC "<<atom_expr->temp_3ac<<endl;
            }
            else {
                q = new quadrup();
                q->gen_quad_variable_decl(atom_expr->temp_3ac+"_3", atom_expr->temp_3ac_2);
                /* parent->tac_codes.push_back(q); */
                atom_expr->tac_codes.push_back(q);
                atom_expr->tac_str += q->code;
                /* parent->tac_str += q->code;  */
                atom_expr->temp_3ac = "*" + atom_expr->temp_3ac_2;
            }
        }
    } else if (entry->type_entry == FUNCTION) {
        // Generate a quadruple for function call
        if(debug_symbol_table) cout<<"Inside get_temp_of_atom_expr : FUNCTION"<<endl;
        stack<node *> call_push_stack;
        int size_push_param=0;

        if(class_table.find(entry->name)!=class_table.end()){
            size_push_param+=8;
        }

        // We are not pushing the parameters in reverse order because we reverse them later
        /* for(node *s: atom_expr->args) {    // reverse parameter order                                    
            call_push_stack.push(s);
            size_push_param+=8;
        }
        
        while(!call_push_stack.empty()) {  // push all parameters onto the stack
            quadrup *q = new quadrup();
            q->gen_func_push_param(call_push_stack.top()->temp_3ac);
            atom_expr->tac_codes.push_back(q);
            atom_expr->tac_str += q->code;
            call_push_stack.pop();
        } */

        if(entry->present_table->category == "C" && !entry->is_init) {
            if(debug_symbol_table) cout<<"PUSHING SELF ONTO FUNCTION STACK"<<endl;
            quadrup *q = new quadrup();
            string name = atom_expr->atom_name[0];
            for(int i = 1; i < atom_expr->atom_name.size()-2; i++){
                name+="_"+atom_expr->atom_name[i];
            }
            q->gen_func_push_param(name);
            atom_expr->tac_codes.push_back(q);
            atom_expr->tac_str += q->code;
            size_push_param+=8;
        }  

         if(atom_expr->args.size() == 1 && atom_expr->args[0]->type_data == STRING && entry->name == "print") {
            // quadrup *q = new quadrup();
            // q->gen_quad_push_param(atom_expr->args[0]->temp_3ac);
            // atom_expr->tac_codes.push_back(q);
            // atom_expr->tac_str += q->code;

            cerr << "PRINT STRING" << endl;
            quadrup *q = new quadrup();
            q -> gen_quad_print_string(atom_expr->args[0]->temp_3ac);
            atom_expr->tac_codes.push_back(q);
            atom_expr->tac_str += q->code;
        }
        else{
        for(node *s: atom_expr->args) {
            size_push_param+=8;
            quadrup *q = new quadrup();
            q->gen_func_push_param(s->temp_3ac);
            atom_expr->tac_codes.push_back(q);
            atom_expr->tac_str += q->code;
        }
        
        // If the function is_init, or member of a class, then add the pointer of the class object to the call stack
        if(debug_symbol_table) cout<<"PRESENT TABLE OF ENTRY IS"<<entry->present_table->name<<endl;
        
        quadrup *q = new quadrup();
        q->gen_quad_stack_pointer("-"+to_string(size_push_param));
        atom_expr->tac_codes.push_back(q);
        atom_expr->tac_str += q->code;

        q = new quadrup();
        q->gen_func_call(get_mangled_name(entry));
        atom_expr->tac_codes.push_back(q);
        atom_expr->tac_str += q->code;

        q = new quadrup();
        q->gen_quad_stack_pointer("+"+to_string(size_push_param));
        atom_expr->tac_codes.push_back(q);
        atom_expr->tac_str += q->code;

        if(entry->type_data == NONE )
        { q = new quadrup();
        q->gen_func_get_retval_none();
        atom_expr->tac_codes.push_back(q);
        atom_expr->tac_str += q->code; }

        
        if(debug_symbol_table) cout<<"The entry name is" << entry->name<<" next table is "<<entry->next_table<<endl;
        symbol_table_generic *temp_table = entry->next_table;
        if(debug_symbol_table) cout<<"Address of next table is "<<temp_table<<endl;
        data_type return_type;
        if(temp_table!=NULL){
            if(debug_symbol_table) cout<<"The name of the next table is "<<temp_table->name<<endl;
            if(debug_symbol_table) cout<<"The return type of the function is "<<temp_table->return_type<<endl;
            return_type = temp_table->return_type;
        } else {
            return_type = NONE;
        }
        if(return_type != NONE) {
            atom_expr->temp_3ac = "t_" + to_string(parent->node_number);
            q = new quadrup();
            q->gen_func_get_retval(atom_expr->temp_3ac);
            atom_expr->tac_codes.push_back(q);
            atom_expr->tac_str += q->code;
        }
        }

        if(debug_symbol_table) cout<<"WOWWW : Returning from this"<<endl;
    }
    else if((entry->type_entry == ARRAY)) {
                if(atom_expr->atom_name.size() > 1) {
            
            string base_class_name = atom_expr->atom_name[0];
            symbol_table_entry *base_class_entry = current_symbol_table.top()->lookup_array(base_class_name);
            string base_class_temp = "";
            if(base_class_entry == NULL && base_class_name != "self") {
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<yylineno-1<<endl;
                cerr<<"Error: Undeclared variable"<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
            }
            else if(base_class_name == "self") {
                // Find object base class pointer
                base_class_temp = "self";
                atom_expr->temp_3ac = base_class_temp;
            } else {
                // Find object base class pointer
                base_class_temp = base_class_entry->base_ptr_3ac;    // IMPLEMENT @Apoorva
                atom_expr->temp_3ac = base_class_temp;
            }

            if((entry->type_entry == ARRAY && lastname=="[]")) {   // looking up an array index
                string offs ="0";
                if(lastname=="[]"){   // lookup the index value
                    offs = (atom_expr->args[atom_expr->args.size()-1]->temp_3ac);
                    if(debug_symbol_table) cout<<"GET_TEMP : OFFS IS "<<offs<<endl;
                }
                
                quadrup* q = new quadrup();
                q->gen_quad_operator("0", offs, atom_expr->temp_3ac+"_1", "+");
                parent->tac_codes.push_back(q);
                if(debug_symbol_table) cout<<"SPECIAL TAC GENERATED : "<<q->code<<endl;
                parent->tac_str += q->code;
                
                q = new quadrup();
                q->gen_quad_operator(atom_expr->temp_3ac+"_1", "8", atom_expr->temp_3ac+"_1", "*");
                parent->tac_codes.push_back(q);
                parent->tac_str += q->code; 

                q = new quadrup();
                q->gen_quad_operator(atom_expr->temp_3ac+"_1", to_string(offset), atom_expr->temp_3ac+"_1", "+");
                parent->tac_codes.push_back(q);
                if(debug_symbol_table) cout<<"SPECIAL TAC GENERATED : "<<q->code<<endl;
                parent->tac_str += q->code;
                
                
            } else {                                                // looking up a variable
                quadrup* q = new quadrup();
                q->gen_quad_operator("0", to_string(offset), atom_expr->temp_3ac+"_1", "+");
                parent->tac_codes.push_back(q);
                if(debug_symbol_table) cout<<"SPECIAL TAC GENERATED : "<<q->code<<endl;
                parent->tac_str += q->code;
            }

            quadrup *q = new quadrup();
            q->gen_quad_variable_lookup_offset(atom_expr->temp_3ac, atom_expr->temp_3ac + "_3",  atom_expr->temp_3ac+"_1");
            parent->tac_codes.push_back(q);
            parent->tac_str += q->code;
    
            if(entry->type_entry == ARRAY && lastname=="[]"){
                atom_expr->temp_3ac = "*" + atom_expr->temp_3ac+"_3";
            }
            else {
                q = new quadrup();
                q->gen_quad_variable_decl(atom_expr->temp_3ac+"_3", atom_expr->temp_3ac_2);
                parent->tac_codes.push_back(q);
                parent->tac_str += q->code; 
                atom_expr->temp_3ac = atom_expr->temp_3ac_2;
            }
        }              
    }
    if(debug_symbol_table) cout<<"RETURNED FROM GET_TEMP_OF_ATOM_EXPR : TEMP_3AC : "<<atom_expr->temp_3ac<<" AT LINE NO "<<atom_expr->lineno<<endl;
}

void print_parse_table(symbol_table_generic *symbol_table_root) {
    cout<<"SYMBOL TABLE"<<","<<"SIZE"<<","<<"ENTRY NAME"<<","<<"ENTRY_TYPE"<<","<<"DATA_TYPE"<<","<<"LINENO"<<","<<"OFFSET"<<endl;

    queue<symbol_table_generic*>to_print;
    to_print.push(symbol_table_root);
    while(!to_print.empty()){
        symbol_table_generic* temp = to_print.front();
        to_print.pop();
        if(!temp) continue;
        if(temp->is_printed == true) continue;
        temp->is_printed = true;
        cout<<endl;
        for(auto entry: temp->entries){
            if(entry == NULL || temp == NULL)continue;
            
            cout<<temp->name<<","<<temp->size<<","<<entry->name<<","<<entrytype[entry->type_entry]<<","<<typedata[entry->type_data]<<","<<entry->lineno<<","<<entry->offset<<endl;

            if(entry->next_table != NULL){
                to_print.push(entry->next_table);
            }
        }
    }


}

void append_tac(node *parent, node *child) {
    for(quadrup *q: child->tac_codes) {
        parent->tac_codes.push_back(q);
        parent->tac_str += q->code;
        /* delete(q); */
    }
    
    child->tac_codes.clear();
    child->tac_str.clear();
    

}

string label_3ac(vector<quadrup*> &tac_codes) {
    
    string code = "";
    int label= 0;
    stack< quadrup*> st;
    for(auto q: tac_codes) {
        
        if(q->is_push_param){
            st.push(q);
            continue;
        }
        else if((q->made_from==quadrup::STACK_POINTER || q->is_alloc == true) && st.size()!=0){
            while(!st.empty()){
                st.top()->code = to_string(label) + ": " + st.top()->code;
                st.top()->ins_line = label;
                code += st.top()->code;
                st.pop();
                label++;
            }
        }
        q->code = to_string(label) + ": " + q->code;
        q->ins_line = label;
        
        if(q->is_jump){
            q->code = q->code + to_string(label + q->rel_jump) +"\n";
            q->rel_jump = label + q->rel_jump;
            q->abs_jump = q->rel_jump;
            goto_targets.push_back(q->abs_jump);
            cerr<<__func__<<" "<<__LINE__<<" : The goto code is "<<q->code<<endl;
        }
        code += q->code;
        label++;
    }
    return code;
}

/* void goto_for_return(vector<quadrup*> & tac_codes){
    long long int size = tac_codes.size();
    long long int last_end_func = size+1;
    for(long long int i= size-1;i>=0;i--){
        if(tac_codes[i]->is_return){
          tac_codes[i]->code += to_string(last_end_func) + "\n";
          tac_codes[i]->rel_jump = last_end_func;
            tac_codes[i]->abs_jump = last_end_func;
            goto_targets.push_back(tac_codes[i]->abs_jump);
        }
        else if(tac_codes[i]->is_end_func){
            last_end_func = tac_codes[i]->ins_line;
    }
}
} */
void reverse_push_param(vector<quadrup*> & tac_codes){
    stack<quadrup*> st;
    vector<quadrup*> new_tac_codes;
    for(auto q: tac_codes){
        if(q->is_push_param){
            st.push(q);
            continue;
        }
        else if((q->made_from==quadrup::STACK_POINTER || q->is_alloc == true) && st.size()!=0){
            while(!st.empty()){
                new_tac_codes.push_back(st.top());
                st.pop();
            }
        }
        new_tac_codes.push_back(q);
    }
    tac_codes = new_tac_codes;

}
/* void print_tac(vector<quadrup*> &tac_codes) {
    for(auto q: tac_codes) {
        cout<<q->code;
    }
} */
void set_jump_targets(vector<quadrup *> &tac_codes) {
    for(int target: goto_targets) {
        if(target >= tac_codes.size()) { // for if __name__ == "__main__" , goto destination goes out of functions cope
            target--;
        }
        tac_codes[target]->is_target = true;
        cerr<<__func__<<" : line number " <<target<<" is a goto target "<<endl;
    }
}

int main(int argc, char *argv[]) {
    string input_name = "";
    string output_name = "asm_code.s";
    string tac_name = "tac.t";
    string symbol_table_name = "symbol_table.csv";
    yydebug = 0;
    /* int generate_parse = 0; */
    int waiting_for_value = 0;
    for(int i = 1; i < argc; i++) {
        string cur_arg = argv[i];
        if(waiting_for_value) {   // Do not attempt to parse values as options
            waiting_for_value = 0;
            continue;
        }
        if (cur_arg == "-i" || cur_arg == "--input") {
            input_name = argv[i + 1];
            waiting_for_value = 1;
        } else if (cur_arg == "-o" || cur_arg == "--output") {
            output_name = argv[i + 1];
            waiting_for_value = 1;
        } else if (cur_arg == "-t" || cur_arg == "--tac") {
            tac_name = argv[i + 1];
            waiting_for_value = 1;
        } else if (cur_arg == "-s" || cur_arg == "--symbol_table") {
            symbol_table_name = argv[i + 1];
            waiting_for_value = 1;
        } else if (cur_arg == "-v" || cur_arg == "--verbose") {
            yydebug = 1;
            debug = 1;
            /* generate_parse = 1; */
            debug_symbol_table = 1;
            print_debug = 1;
            print_debug2 = 1;
        } else if (cur_arg == "-h" || cur_arg == "--help") {
            cout << "Usage: ./gmc -i <input_file> -o <output_file> -v" << endl;
            cout << "Options: " << endl;
            cout << "-i, --input: Input file name [Default - stdin]" << endl;
            cout << "-o, --output: Output file name (for x86) [Default - asm_code.s]" << endl;
            cout << "-t, --tac: Output file name (for tac) [Default - tac.t]" << endl;
            cout << "-s, --symbol_table: Output file name (for symbol table) [Default - symbol_table.csv]" << endl;
            cout << "-v, --verbose: Debug mode" << endl;
            cout << "-h, --help: Display this help message" << endl;
            return 0;
        } else {
            cout << "Unrecognized command line argument " << cur_arg << endl;
            return 1;
        }
    }
    if(yydebug || debug_symbol_table) {
        freopen("gmc_stdout.txt", "w", stdout);
        freopen("gmc_stderr.txt", "w", stderr);
    }
    if(input_name != "") { // Configure input redirection
        freopen(input_name.c_str(), "r", stdin);
    }
    INDENT_stack.push(-1);
    
    symbol_table_generic* root = new symbol_table_generic("Root", "R", 0);
    current_symbol_table.push(root);
    symbol_table_root = root;
    
    symbol_table_entry *print_entry = new symbol_table_entry("print", NONE , root, 0);
    print_entry->type_entry = FUNCTION;
    root->add_entry(print_entry);

    symbol_table_entry * name = new symbol_table_entry("__name__" , STRING , root, 0);
    name->type_entry = VARIABLE;
    root->add_entry(name);
    
    symbol_table_entry *range_entry = new symbol_table_entry("range" , NONE , root, 0);
    range_entry->type_entry = FUNCTION;
    root->add_entry(range_entry);

    symbol_table_entry *len_entry = new symbol_table_entry("len" , NONE , root, 0);
    len_entry->type_entry = FUNCTION;
    root->add_entry(len_entry);
    
    yyparse();
    
    freopen(symbol_table_name.c_str(), "w", stdout);
    print_parse_table(symbol_table_root);

    freopen(tac_name.c_str(), "w", stdout);

    cout<<label_3ac(start_node->tac_codes)<<endl;
    
    reverse_push_param(start_node->tac_codes);
    
    set_jump_targets(start_node->tac_codes);
    /* goto_for_return(start_node->tac_codes);
    
    print_tac(start_node->tac_codes); */
    if(yydebug)
        freopen("debug_asm.txt", "w", stderr);

    /* cerr << "Starting code generation" << endl; */
    ASM* code_asm = new ASM(); 
    code_asm->global_generation(start_node);
    code_asm->text_generation(start_node);
    string filename = output_name;
    code_asm->print_code(filename); 

    /* string ast_dot = output_name + ".dot";
    string ast_pdf = output_name + ".pdf";
    /* cout<<ast_pdf<<' '<<ast_dot<<endl; 
    char ast_dot_str[256];
    strcpy(ast_dot_str, ast_dot.c_str());
    char ast_pdf_str[256];
    strcpy(ast_pdf_str, ast_pdf.c_str());
    /* cout<<ast_pdf_str<<' '<<ast_dot_str<<endl; 
    start_node->make_ast_dot(ast_dot);
    char *args[]= { (char *)"dot", (char *)"-Tpdf", ast_dot_str, (char *)"-o", ast_pdf_str, NULL};
    if(execvp("dot", args)) cout<<"Exec error"<<endl; */

    return 0;
} 