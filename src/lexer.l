%{
    #include <bits/stdc++.h>
    #include <string>
    #include "new_grammar.tab.h"

    // extern "C" int yylex();
    using namespace std;

    #define YY_DECL extern "C" int yylex()
    void err (const char* s)
    {
        if(s == NULL) {
            printf("Error in memory allocation");
            exit(0);
        }
    }

    int cur_indent = 0;  // Actual Indentation level in worth of spaces
    stack<int> INDENT_stack;
    stack<int> IMPLICIT_Line;
    int return_token = 1;   // Will return tokens if enabled
    int print_debug = 0;    // Will print debug if enabled
    int print_debug2 = 0;   // Will print debug if enabled
    int dedent_state = 0;
    int newline = 0;
    int indent_state = 0;
%}

%option yylineno
%option nounput
DIGIT                    [0-9]
NONZERO_DIGIT            [1-9]
HEX_DIGIT                [0-9a-fA-F]
ASCII                    [\x00-\x7F]
OCT_DIGIT                [0-7]
BIN_DIGIT                [01]
DIGIT_PART               {DIGIT}({DIGIT}|([_]{DIGIT}))*
EXPONENT                 [eE]([+-]?){DIGIT_PART}
FRACTION                 "."{DIGIT_PART}
HEX_INTEGER              0[xX]({HEX_DIGIT}|(_{HEX_DIGIT}))+
DEC_INTEGER              ({NONZERO_DIGIT}({DIGIT}|([_]{DIGIT}))*)|(0(0|([_]0))*)
OCT_INTEGER              0[oO]({OCT_DIGIT}|(_{OCT_DIGIT}))+
BIN_INTEGER              0[bB]({BIN_DIGIT}|(_{BIN_DIGIT}))+
POINT_FLOAT              ({DIGIT_PART}?{FRACTION})|({DIGIT_PART}".")
EXPONENT_FLOAT           ({DIGIT_PART}|{POINT_FLOAT}){EXPONENT}
BYTES_ESCAPE_SEQ         "\\"{ASCII}
LONG_BYTES_CHAR          {ASCII}-[\\]
SHORT_BYTES_CHAR         {ASCII}-[\\\"\'\n]
LONG_BYTES_ITEM          {LONG_BYTES_CHAR}|{BYTES_ESCAPE_SEQ}
SHORT_BYTES_ITEM         {SHORT_BYTES_CHAR}|{BYTES_ESCAPE_SEQ}
LONG_BYTES               ("'''"[{LONG_BYTES_ITEM}]*"'''")|(\"\"\"[{LONG_BYTES_ITEM}]*\"\"\")
SHORT_BYTES              ("'''"[{SHORT_BYTES_ITEM}]*"'''")|(\"\"\"[{SHORT_BYTES_ITEM}]*\"\"\")
BYTES_PREFIX              "b"|"B"|"br"|"Br"|"bR"|"BR"|"rb"|"rB"|"Rb"|"RB"
LITERAL_CHAR             [^\{\}\0]
CONVERSION               "s"|"r"|"a"
STRING_ESCAPE_SEQ        "\"{ASCII}
LONG_STRING_CHAR         {ASCII}-[\\]
SHORT_STRING_CHAR        {ASCII}-[\\\"\'\n]
LONG_STRING_ITEM         {LONG_STRING_CHAR}|{STRING_ESCAPE_SEQ}
SHORT_STRING_ITEM        {SHORT_STRING_CHAR}|{STRING_ESCAPE_SEQ}
LONG_STRING              ((\'\'\')({LONG_STRING_ITEM})*(\'\'\'))|((\"\"\")({LONG_STRING_ITEM})*(\"\"\"))
SHORT_STRING             ((\')({SHORT_STRING_ITEM})*(\'))|((\")({SHORT_STRING_ITEM})*(\"))
STRING_PREFIX             "b"|"B"|"br"|"Br"|"bR"|"BR"|"rb"|"rB"|"Rb"|"RB"
NAME                     [A-Za-z_][A-Za-z0-9_]*
WS                       [ \t\f]+
COMMENT                  "#"[^\n]*
INTEGER                  {DEC_INTEGER}|{BIN_INTEGER}|{OCT_INTEGER}|{HEX_INTEGER}
FLOAT_NUMBER             ({POINT_FLOAT}|{EXPONENT_FLOAT})
IMAG_NUMBER              ({FLOAT_NUMBER}|{DIGIT_PART})[jJ]
SINGLE                   \'[^\'\\]*(?:\\.[^\'\\]*)*\'
DOUBLE                   \"[^\"\\]*(?:\\.[^\"\\]*)*\"
SINGLE3                  \'\'\'[^\'\\]*\'\'\'
DOUBLE3                  \"\"\"[^\"\\]*\"\"\"
STRING_LITERAL           {DOUBLE}|{SINGLE}|{DOUBLE3}|{SINGLE3}
INDENT_SPACE             [\n][ \t\f]*
INDENT_SPACE2            ^[ \t\f]*
END_MARKER               <<EOF>>
NEW_LINE                 [\n]

%%
    {   if(!IMPLICIT_Line.empty()) {
        }
        else {if(newline){
            if(print_debug2) printf("printing newline %d\n", yylineno);
            newline=0;
           if(return_token)return NEWLINE;
        }
        if(dedent_state == 1) {
                if(print_debug2) printf("Going to DEDENT_STATE\n");
                if(cur_indent < INDENT_stack.top()) {
                    INDENT_stack.pop();
                    if(return_token) return DEDENT;
                }
                else {

                    dedent_state = 0;
                }
        }  
        if(indent_state == 1) {
            int zero_indent = 0;                     // Do not generate indent if going from -1 to 0
            if(cur_indent > INDENT_stack.top()) {
                if(cur_indent == 0) zero_indent = 1;
                INDENT_stack.push(cur_indent);
                if(return_token && !zero_indent ) return (INDENT);
            }
            indent_state = 0;
        }}
    }

{NEW_LINE}({COMMENT}|{WS})*$     {
    string s = yytext;

}

{INDENT_SPACE} {
    if(!IMPLICIT_Line.empty()) {
    }
    else {
    newline=1;
    
    if(print_debug2) printf("AFTER YYLEXs\n");
    int min_indent = 0;
    int max_indent = 0;
    int indent = 0;

    string s = yytext;
    for(auto c : s) {
        if(c == ' ') {
            indent++;
            min_indent++;
            max_indent++;
        }
        else if(c == '\t') {
            indent = (indent + 8) - (indent % 8);
            min_indent++;
            max_indent += 8;
        }
        else if(c == '\f') 
            continue;
    }
    cur_indent = indent;
    if(print_debug2) printf("Indent: %d\n", cur_indent);
    if(cur_indent > INDENT_stack.top()) {
        indent_state = 1;
    }
    else if(cur_indent < INDENT_stack.top()) {
        dedent_state = 1;
    }
    return yylex();
    }
}

{INDENT_SPACE2}  {
}

"..." { yylval.strval  = strdup(yytext); }
"False" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_False, Line: %d\n", yylineno); if(return_token) return (KEYWORD_False); }
"else" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_else, Line: %d\n", yylineno); if(return_token) return (KEYWORD_else); }
"None" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_None, Line: %d\n", yylineno); if(return_token) return (KEYWORD_None); }
"break" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_break, Line: %d\n", yylineno); if(return_token) return (KEYWORD_break); }
"in" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_in, Line: %d\n", yylineno); if(return_token) return (KEYWORD_in); }
"True" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_True, Line: %d\n", yylineno); if(return_token) return (KEYWORD_True); }
"class" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_class, Line: %d\n", yylineno); if(return_token) return (KEYWORD_class); }
"is" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_is, Line: %d\n", yylineno); if(return_token) return (KEYWORD_is); }
"return" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_return, Line: %d\n", yylineno); if(return_token) return (KEYWORD_return); }
"and" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_and, Line: %d\n", yylineno); if(return_token) return (KEYWORD_and); }
"continue" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_continue, Line: %d\n", yylineno); if(return_token) return (KEYWORD_continue); }
"for" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_for, Line: %d\n", yylineno); if(return_token) return (KEYWORD_for); }
"def" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_def, Line: %d\n", yylineno); if(return_token) return (KEYWORD_def); }
"while" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_while, Line: %d\n", yylineno); if(return_token) return (KEYWORD_while); }
"global" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_global, Line: %d\n", yylineno); if(return_token) return (KEYWORD_global); }
"not"    { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_not, Line: %d\n", yylineno); if(return_token) return (KEYWORD_not); }
"elif"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_elif, Line: %d\n", yylineno); if(return_token) return (KEYWORD_elif); }
"if"     { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_if, Line: %d\n", yylineno); if(return_token) return (KEYWORD_if); }
"or"     { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_or, Line: %d\n", yylineno); if(return_token) return (KEYWORD_or); }
"int"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_int, Line: %d\n", yylineno); if(return_token) return (KEYWORD_int); }
"float" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_float, Line: %d\n", yylineno); if(return_token) return (KEYWORD_float); }
"complex" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_complex, Line: %d\n", yylineno); if(return_token) return (KEYWORD_complex); }
"str" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_str, Line: %d\n", yylineno); if(return_token) return (KEYWORD_str); }
"bool" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_bool, Line: %d\n", yylineno); if(return_token) return (KEYWORD_bool); }
"list" { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: KEYWORD_list, Line: %d\n", yylineno); if(return_token) return (KEYWORD_List); }
"+"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_add, Line: %d\n", yylineno); if(return_token) return (OPERATOR_add); }
"-"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_subtract, Line: %d\n", yylineno); if(return_token) return (OPERATOR_subtract); }
"*"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_multiply, Line: %d\n", yylineno); if(return_token) return (OPERATOR_multiply); }
"**"  { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_power, Line: %d\n", yylineno); if(return_token) return (OPERATOR_power); }
"/"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_divide, Line: %d\n", yylineno); if(return_token) return (OPERATOR_divide); }
"//"  { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_floor_divide, Line: %d\n", yylineno); if(return_token) return (OPERATOR_floor_divide); }
"%"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_modulo, Line: %d\n", yylineno); if(return_token) return (OPERATOR_modulo); }
"<<"  { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_left_shift, Line: %d\n", yylineno); if(return_token) return (OPERATOR_left_shift); }
">>"  { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_right_shift, Line: %d\n", yylineno); if(return_token) return (OPERATOR_right_shift); }
"&"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_bitwise_and, Line: %d\n", yylineno); if(return_token) return (OPERATOR_bitwise_and); }
"|"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_bitwise_or, Line: %d\n", yylineno); if(return_token) return (OPERATOR_bitwise_or); }
"^"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_bitwise_xor, Line: %d\n", yylineno); if(return_token) return (OPERATOR_bitwise_xor); }
"~"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_bitwise_not, Line: %d\n", yylineno); if(return_token) return (OPERATOR_bitwise_not); }
"<"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_less_than, Line: %d\n", yylineno); if(return_token) return (OPERATOR_less_than); }
">"   { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_greater_than, Line: %d\n", yylineno); if(return_token) return (OPERATOR_greater_than); }
"<="  { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_less_than_or_equal, Line: %d\n", yylineno); if(return_token) return (OPERATOR_less_than_or_equal); }
">="  { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_greater_than_or_equal, Line: %d\n", yylineno); if(return_token) return (OPERATOR_greater_than_or_equal); }
"=="  { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_equal, Line: %d\n", yylineno); if(return_token) return (OPERATOR_equal); }
"!="  { yylval.strval  = strdup(yytext);  if(print_debug) printf("Token: OPERATOR_not_equal, Line: %d\n", yylineno); if(return_token) return (OPERATOR_not_equal); }

")"   { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_close_parenthesis, Line: %d\n", yylineno); IMPLICIT_Line.pop();  if(return_token) return (DELIMITER_close_parenthesis); }
"("   { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_open_parenthesis, Line: %d\n", yylineno); IMPLICIT_Line.push(1); if(return_token) return (DELIMITER_open_parenthesis); }
"["   { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_open_square_bracket, Line: %d\n", yylineno); IMPLICIT_Line.push(1); if(return_token) return (DELIMITER_open_square_bracket); }
"]"   { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_close_square_bracket, Line: %d\n", yylineno); IMPLICIT_Line.pop(); if(return_token) return (DELIMITER_close_square_bracket); }
","   { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_comma, Line: %d\n", yylineno); if(return_token) return (DELIMITER_comma); }
":"   { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_colon, Line: %d\n", yylineno); if(return_token) return (DELIMITER_colon); }
"."   { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_dot, Line: %d\n", yylineno); if(return_token) return (DELIMITER_dot); }
";"   { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_semicolon, Line: %d\n", yylineno); if(return_token) return (DELIMITER_semicolon); }
"="   { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_equal); }
"->"  { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_arrow, Line: %d\n", yylineno); if(return_token) return (DELIMITER_arrow); }
"+="  { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_plus_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_plus_equal); }
"-="  { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_minus_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_minus_equal); }
"*="  { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_multiply_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_multiply_equal); }
"/="  { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_divide_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_divide_equal); }
"//=" { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_floor_divide_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_floor_divide_equal); }
"%="  { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_modulo_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_modulo_equal); }
"&="  { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_bitwise_and_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_bitwise_and_equal); }
"|="  { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_bitwise_or_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_bitwise_or_equal); }
"^="  { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_bitwise_xor_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_bitwise_xor_equal); }
">>=" { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_right_shift_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_right_shift_equal); }
"<<=" { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_left_shift_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_left_shift_equal); }
"**=" { yylval.strval  = strdup(yytext);   if(print_debug) printf("Token: DELIMITER_power_equal, Line: %d\n", yylineno); if(return_token) return (DELIMITER_power_equal); }

{FLOAT_NUMBER}  {
                            yylval.strval = strdup(yytext); 
    if(print_debug) printf("Token: LITERAL_floatingpoint, Value: %s, Line: %d\n", yytext, yylineno);
    if(return_token) return (LITERAL_floatingpoint); 
}

{NAME}  {
                            yylval.strval = strdup(yytext); 
    if(print_debug) printf("Token: NAME, Value: %s, Line: %d\n", yytext, yylineno);
    if(return_token) return (NAME); 
}

{COMMENT}  {
    // cout<<"COMMENT FOUND"<<"\n";
    if(print_debug) printf("Token: COMMENT, Line: %d\n", yylineno);
}

{STRING_LITERAL}  {
    string s = yytext;
    // string s2= s.substr(1,s.size()-2);
    char * s3 = strdup(s.c_str());
    string s2 = s3;
    yylval.strval = s3; 
    if(print_debug) printf("Token: LITERAL_string, Value: %s, Line: %d\n", yytext, yylineno);
    if(return_token) return (LITERAL_string); 
}

{INTEGER}  {                            yylval.strval = strdup(yytext); 
    if(print_debug) printf("Token: LITERAL_integer, Value: %s, Line: %d\n", yytext, yylineno);
    if(return_token) return (LITERAL_integer); 
} 

{IMAG_NUMBER}  {
    yylval.strval = strdup(yytext); 
    if(print_debug) printf("Token: LITERAL_imag, Value: %s, Line: %d\n", yytext, yylineno);
    if(return_token) return (LITERAL_imag); 
}

{WS}       {}

%%

// int main(){
//     INDENT_stack.push(0);
//     yylex();
// }