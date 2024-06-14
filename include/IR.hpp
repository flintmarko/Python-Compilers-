#include <bits/stdc++.h>
#include "symbol_table.hpp"
using namespace std;

struct quadrup {
	string op = "";
    string arg1 = "";
    string arg2 = "";
    string result = "";
    string code = "";        // Construct from each node
    int rel_jump = 0, abs_jump = 0, ins_line = 0;
    int made_from = 0;
    bool is_target = false;
    bool is_jump = false;
    int num_tabs = 0;
    bool is_break = false;
    bool is_continue = false;
    bool is_push_param = false;
    bool is_alloc = false;
    bool is_end_func = false;
    bool is_return = false;
    bool reljump_else = false;

    enum code_code {
        BINARY,
        UNARY,
        ASSIGNMENT,
        CONDITIONAL,
        STORE,
        LOAD,
        FUNC_CALL,
        GOTO,
        BEGIN_FUNC,
        END_FUNC,
        RETURN,
        STACK_POINTER,
        PUSH_PARAM,
        POP_PARAM,
        RETURN_VAL,
        RETURN_NONE,
        RETURN_NONE_calle,
        PRINT_STR,
        STR_CMP,
        RETURN_VAL_STRCMP
    };

    quadrup() {
        this->op = "";
        this->arg1 = "";
        this->arg2 = "";
        this->result = "";
        this->code = "";
        this->rel_jump = 0;
        this->abs_jump = 0;
        this->ins_line = 0;
        this->made_from = 0;
        this->is_target = false;
        this->num_tabs = 0;
        this->is_push_param = false;
    }

    quadrup(int num_tabs) {
        this->op = "";
        this->arg1 = "";
        this->arg2 = "";
        this->result = "";
        this->code = "";
        for(int i = 0; i < num_tabs; i++) {
            code+="\t";
        }
        this->rel_jump = 0;
        this->abs_jump = 0;
        this->ins_line = 0;
        this->made_from = 0;
        this->is_target = false;
    }

    quadrup(string r, string a1, string o, string a2) {
        op = o;
        arg1 = a1;
        arg2 = a2;
        result = r;
        code = "";
        rel_jump = 0;
        abs_jump = 0;
        ins_line = 0;
        made_from = 0;
        is_target = false;
    }


    void gen_quad_variable_lookup_offset(string arg1, string result, int offset) {
        this->op = "+";
        this->arg1 = arg1;
        this->arg2 = to_string(offset);
        this->result = result;
        this->code += result + " = " + arg1 + " + " + to_string(offset) + "\n";
        this->made_from = BINARY;
    }

    void gen_quad_variable_lookup_offset(string arg1, string result, string offset) {
        this->op = "+";
        this->arg1 = arg1;
        this->arg2 = offset;
        this->result = result;
        this->code += result + " = " + arg1 + " + " + offset + "\n";
        this->made_from = BINARY;
    }

    void gen_quad_variable_dereference(string arg1, string result) {
        this->op = "*";
        this->arg1 = "*" + arg1;
        this->arg2 = "";
        this->result = result;
        this->code += result + " = " + this->arg1 + "\n";
        this->made_from = LOAD;
    }

    void gen_quad_variable_dereference_left(string arg1, string result) {  
        this->op = "*";
        this->arg1 = arg1;
        this->arg2 = "";
        this->result = "*" + result;
        this->code +=  this->result + " = " + arg1 + "\n";
        this->made_from = STORE;
    }
    
    void gen_quad_variable_decl(string arg1, string result) {
        this->op = "=";
        this->arg1 = arg1;
        this->arg2 = "";
        this->result = result;
        this->code += result + " = " + arg1 + "\n";
        this->made_from = ASSIGNMENT;
        if(arg1[0]=='*'){
            this->made_from = LOAD;
        }
        else if(result[0]=='*'){
            this->made_from = STORE;
        }
    }
   
    void gen_quad_push_param(string arg1) {
        this->op = "push_param";
        this->arg1 = arg1;
        this->arg2 = "";
        this->result = "";
        this->code += "push_param " + arg1 + "\n";
        this->is_push_param = true;
        this->made_from = PUSH_PARAM;

    }

    void gen_func_push_param_strcmp(string arg1, string arg2) {
        this->op = "push_param";
        this->arg1 = arg1;
        this->arg2 = arg2;
        this->result = "";
        this->code += "push_strcmp " + arg1 + " " + arg2 +"\n";
        this->is_push_param = false;
        this->made_from = STR_CMP;

    }
    void gen_quad_call_func(string arg1) {
        this->op = "call_func";
        this->arg1 = arg1;
        if(arg1 == "print") {
            arg1 = "do_print";
        }
        this->arg2 = "";
        this->result = "";
        if(arg1 == "print") {
            arg1 = "do_print";
            this->code += "call_func " + arg1 + "\n";
            this->made_from = FUNC_CALL;

        }
        else {

        this->code += "call_func " + arg1 + "\n";
        this->made_from = FUNC_CALL;
        }
        if(arg1=="allocmem"){
            this->is_alloc = true;
        }

    }
    
    void gen_quad_operator(string arg1, string arg2, string result, string op) {
        this->op = op;
        this->arg1 = arg1;
        this->arg2 = arg2;
        this->result = result;
        this->code += result + " = " + arg1 + " " + op + " " + arg2 + "\n";
        if(arg1 == ""){
            this->made_from = UNARY;
        }
        else{
            this->made_from = BINARY;
        }
    }

    void gen_quad_pop_param(string result) {
        this->op = "pop_param";
        this->arg1 = "";
        this->arg2 = "";
        this->result = result;
        this->code += result + " = " + "pop_param \n";
        this->made_from = POP_PARAM;
    }
    
    void gen_quad_if_false(string arg1, string arg2){
        // if false arg1 goto agr2
        this->op = "IF_FALSE";
        this->arg1 = arg1;
        this->arg2 = arg2;
        this->result = "";
        this->is_jump = true;
        this->reljump_else = false;
        string s="";
        for(auto i: arg2){
        
            if((i >= '0' && i<='9') || i == '-'){
                s+=i;
            }
        }
        this->rel_jump = atoi(s.c_str());
        this->code += "IF_FALSE " + arg1 + " GOTO " ;
        cout<<__func__<<" : If false code when generated is " << this->code << " and reljump is "<<this->rel_jump<<endl;
        this->made_from = CONDITIONAL;
    }

     // added by krish

    
    void gen_quad_print_string(string arg1){
        this->op = "PRINT_STR";
        this->arg1 = arg1;
        this->arg2 = "";
        this->result = "";
        this->code += "PRINT_STR " + arg1 + "\n";
        this->made_from = PRINT_STR;
    }
//    void gen_quad_goto_return(){
//     this->op = "GOTO";
//     this->arg1 = "";
//             this->arg2 = "";
//         this->result = "";
//         this->code += "GOTO ";
//         this->is_return = true;
//         this->made_from = GOTO;

//    } 
    void gen_quad_goto(string arg1){
        this->op = "GOTO";
        this->arg1 = arg1;
        if(arg1 == "break"){
            this->is_jump = true;
            this->is_target = true;
            this->is_break = true;
        }
        else if(arg1 == "continue"){
            this->is_jump = true;
            this->is_target = true;
            this->is_continue = true;
        }
        else { 
            this->arg2 = "";
            this->result = "";
            this->is_jump = true;
            string s="";
            for(auto i: arg1){
            
                if(i >= '0' && i<='9' || i == '-'){
                    s+=i;
                }
            }
        this->rel_jump = atoi(s.c_str());
        this->code += "GOTO " ;
        }
        this->made_from = GOTO;
    }

    void gen_func_push_param(string arg1) {
        this->op = "func_push_param";
        this->arg1 = arg1;
        this->arg2 = "";
        this->result = "";
        this->code += "push_param " + arg1 + "\n";
        this->is_push_param = true;
        this->made_from = PUSH_PARAM;
    }

    void gen_func_pop_param(string result) {
        this->op = "func_pop_param";
        this->arg1 = "";
        this->arg2 = "";
        this->result = result;
        this->code += result + " = " + "pop_param \n";
        this->made_from = POP_PARAM;
    }
    
    void gen_func_call(string arg1) {
        this->op = "func_call";
        this->arg1 = arg1;
        if(arg1 == "print") {
            arg1 = "do_print";
        }
        this->arg2 = "";
        this->result = "";
        this->code += "call_func " + arg1 + "\n";
        this->made_from = FUNC_CALL;
    }

    void gen_func_decl(string arg1) {
        this->op = "func_decl";
        this->arg1 = arg1;
        this->arg2 = "";
        this->result = "";
        this->code += "begin_func " + arg1 + "\n";
        this->made_from = BEGIN_FUNC; 
    }

    void gen_func_get_retval(string result) {
        this->op = "func_get_retval";
        this->arg1 = "";
        this->arg2 = "";
        this->result = result;
        this->code += result + " = " + "return_value \n";
        this->made_from = RETURN_VAL; 
    }

        void gen_func_get_retval_strcmp(string result) {
        this->op = "func_get_retval";
        this->arg1 = "";
        this->arg2 = "";
        this->result = result;
        this->code += result + " = " + "return_value \n";
        this->made_from = RETURN_VAL_STRCMP; 
    }

    void gen_func_get_retval_none(){
        this->op = "func_get_retval";
        this->arg1 = "";
        this->arg2 = "";
        this->result = "";
        this->code += "return_none \n";
        this->made_from = RETURN_NONE;
    }
    void gen_quad_end_func(){
        this->op = "end_func";
        this->arg1 = "";
        this->arg2 = "";
        this->result = "";
        this->code += "end_func\n";
        this->made_from = END_FUNC;
        this->is_end_func = true;
    }

    void gen_quad_return(string arg1){
        this->op = "return";
        this->arg1 = arg1;
        this->arg2 = "";
        this->result = "";
        this->code += "return " + arg1 + "\n";
        if(arg1 == "")this->made_from = RETURN_NONE_calle;
        else this->made_from = RETURN;
    }

    void gen_quad_stack_pointer(string arg1){
        this->op = "stack_pointer";
        this->arg1 = arg1;
        this->arg2 = "";
        this->result = "";
        this->code += "stack_pointer " + arg1 + "\n";
        this->made_from = STACK_POINTER;
    }
};
