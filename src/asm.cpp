#include "../include/asm.hpp"
#include <iostream>

using namespace std;

const int stack_offset = 8;
int func_count = 0;
map<string, string> func_name_map;
map<string, string> m;
int cntr_loop = 0;

ASM::ASM(){;}

ASM::ASM(string op, string a1, string a2, string a3, string it) : op(op), arg1(a1), arg2(a2), arg3(a3), ins_type(it){
    if(it == "ins") {           // default inss
        if(arg3 == "") {
            code = " " + op;
            if(arg1 != ""){
                code += " " + arg1;
            } 
            if(arg2 != ""){
                code += ", " + arg2;
            }
        }
        else {

        }
    }
    else if(it == "segment") {  // text segment, global segment
        code = op;
        if(a1 != "") {
            code += " " + a1;
        }
    }
    else if(it == "label") {    // jump labels and activation labels
        code = arg1 + ":";
    }
    code += "\n";
}


string ASM::function_dedo(string s) {
    if(func_name_map.find(s) == func_name_map.end()) {
        func_count++;
        func_name_map[s] = "fn" + to_string(func_count);
    }

    return func_name_map[s];
}

vector<ASM> ASM::assembly_generation(quadrup q, int x, int y, int z){
    vector<ASM> insts;
    ASM ins;

    //cerr<< __func__<< " : The tac we are converting is "<<q.code<<endl;
    if(q.code == ""){
        return insts;
    }
    else{
        // if(q.made_from != quadrup::STACK_POINTER && q.made_from != quadrup::POP_PARAM){
        //     ins = ASM("", "", "", "", "comment", q.code.substr(2, q.code.size() - 2));
        //     insts.push_back(ins);
        // }
    }

    if(q.is_target) {   // if this is a target, a label needs to be added
        ins = ASM("", "L" + to_string(q.ins_line), "", "", "label");
        insts.push_back(ins);
    }
    if(q.made_from == quadrup::BINARY){            // c(z) = a(x) op b(y)
        // Load value of a into %rax

        if(q.op == "+"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("add", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("add", to_string(y) + "(%rbp)", "%rdx");
            }
        }
        else if(q.op == "-"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("sub", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("sub", to_string(y) + "(%rbp)", "%rdx");
            }
        }
        else if(q.op == "*"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("imul", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("imul", to_string(y) + "(%rbp)", "%rdx");
            }
        }
        else if(q.op == "**"){
            if (!is_variable(q.arg1)) {
                ins = ASM("movq", "$" + q.arg1, "%rax");
            } 
            else {
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rax");
            }
            insts.push_back(ins);

            if (!is_variable(q.arg2)) {
                ins = ASM("movq", "$" + q.arg2, "%rcx");
            } 
            else {
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rcx");
            }
            insts.push_back(ins);

            ins = ASM("movq", "$1", "%rdx");
            insts.push_back(ins);

            ins = ASM("loop_power"+to_string(cntr_loop)+":");
            insts.push_back(ins);

            ins = ASM("test", "%rcx", "%rcx");
            insts.push_back(ins);

            ins = ASM("jz", "end_power"+to_string(cntr_loop));
            insts.push_back(ins);

            ins = ASM("imul", "%rax", "%rdx");
            insts.push_back(ins);

            ins = ASM("dec", "%rcx");
            insts.push_back(ins);

            ins = ASM("jmp", "loop_power"+to_string(cntr_loop));
            insts.push_back(ins);

            ins = ASM("end_power"+to_string(cntr_loop)+":");
            insts.push_back(ins);

            ins = ASM("movq", "%rdx", to_string(z) + "(%rbp)");
            insts.push_back(ins);

            cntr_loop++;

        }
        else if(q.op == "/"){
            if(!is_variable(q.arg1)){   // arg1 is a literal
                ins = ASM("movq", "$" + q.arg1, "%rax");
                insts.push_back(ins);
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rax");
                insts.push_back(ins);                
            }
            ins = ASM("cqto");
            insts.push_back(ins);

            if(!is_variable(q.arg2)){  // arg2 is a literal
                ins = ASM("movq", "$" + q.arg2, "%rbx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rbx");
            }
            insts.push_back(ins);
            ins = ASM("idiv", "%rbx", "");
            insts.push_back(ins);
            ins = ASM("movq", "%rax", "%rdx");
        }
        else if(q.op == "//"){
            if(!is_variable(q.arg1)){ // arg1 is a literal
                ins = ASM("movq", "$" + q.arg1, "%rax");
                insts.push_back(ins);
            } 
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rax");
                insts.push_back(ins);
            }
            ins = ASM("cqto");
            insts.push_back(ins);
            if(!is_variable(q.arg2)){ // arg2 is a literal
                ins = ASM("movq", "$" + q.arg2, "%rbx");
            } 
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rbx");
            }
            insts.push_back(ins);
            ins = ASM("idivq", "%rbx", "");
            insts.push_back(ins);
            ins = ASM("movq", "%rax", "%rdx");
            insts.push_back(ins);
        }
        else if(q.op == "%"){
            if(!is_variable(q.arg1)){   // arg1 is a literal
                ins = ASM("movq", "$" + q.arg1, "%rax");
                insts.push_back(ins);
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rax");
                insts.push_back(ins);                
            }
            ins = ASM("cqto");
            insts.push_back(ins);

            if(!is_variable(q.arg2)){  // arg2 is a literal
                ins = ASM("movq", "$" + q.arg2, "%rbx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rbx");
            }
            insts.push_back(ins);
            ins = ASM("idiv", "%rbx", "");
        }
        else if(q.op == "<<"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rcx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rcx");
            }
            insts.push_back(ins);
            ins = ASM("sal", "%cl", "%rdx");
        }
        else if(q.op == ">>"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rcx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rcx");
            }
            insts.push_back(ins);
            ins = ASM("sar", "%cl", "%rdx");
        }
        else if(q.op == ">"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);

            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rcx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rcx");
            }
            insts.push_back(ins);
            ins = ASM("cmp", "%rdx", "%rcx");
            insts.push_back(ins);
            ins = ASM("jl", "1f");  // true
            insts.push_back(ins);
            ins = ASM("movq", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f"); // false
            insts.push_back(ins);
            ins = ASM("", "1", "", "", "label");
            insts.push_back(ins);
            ins = ASM("movq", "$1", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f");
            insts.push_back(ins);
            ins = ASM("", "2", "", "", "label");
        }
        else if(q.op == "<"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);

            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rcx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rcx");
            }
            insts.push_back(ins);
            ins = ASM("cmp", "%rdx", "%rcx");
            insts.push_back(ins);
            ins = ASM("jg", "1f");  // true
            insts.push_back(ins);
            ins = ASM("movq", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f"); // false
            insts.push_back(ins);
            ins = ASM("", "1", "", "", "label");
            insts.push_back(ins);
            ins = ASM("movq", "$1", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f");
            insts.push_back(ins);
            ins = ASM("", "2", "", "", "label");
        }
        else if(q.op == ">="){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);

            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rcx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rcx");
            }
            insts.push_back(ins);
            ins = ASM("cmp", "%rdx", "%rcx");
            insts.push_back(ins);
            ins = ASM("jle", "1f");  // true
            insts.push_back(ins);
            ins = ASM("movq", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f"); // false
            insts.push_back(ins);
            ins = ASM("", "1", "", "", "label");
            insts.push_back(ins);
            ins = ASM("movq", "$1", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f");
            insts.push_back(ins);
            ins = ASM("", "2", "", "", "label");
        }
        else if(q.op == "<="){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);

            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rcx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rcx");
            }
            insts.push_back(ins);
            ins = ASM("cmp", "%rdx", "%rcx");
            insts.push_back(ins);
            ins = ASM("jge", "1f");  // true
            insts.push_back(ins);
            ins = ASM("movq", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f"); // false
            insts.push_back(ins);
            ins = ASM("", "1", "", "", "label");
            insts.push_back(ins);
            ins = ASM("movq", "$1", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f");
            insts.push_back(ins);
            ins = ASM("", "2", "", "", "label");
        }
        else if(q.op == "=="){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);

            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rcx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rcx");
            }
            insts.push_back(ins);
            ins = ASM("cmp", "%rdx", "%rcx");
            insts.push_back(ins);
            ins = ASM("je", "1f");  // true
            insts.push_back(ins);
            ins = ASM("movq", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f"); // false
            insts.push_back(ins);
            ins = ASM("", "1", "", "", "label");
            insts.push_back(ins);
            ins = ASM("movq", "$1", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f");
            insts.push_back(ins);
            ins = ASM("", "2", "", "", "label");
        }
        else if(q.op == "!="){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);

            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rcx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rcx");
            }
            insts.push_back(ins);
            ins = ASM("cmp", "%rdx", "%rcx");
            insts.push_back(ins);
            ins = ASM("jne", "1f");  // true
            insts.push_back(ins);
            ins = ASM("movq", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f"); // false
            insts.push_back(ins);
            ins = ASM("", "1", "", "", "label");
            insts.push_back(ins);
            ins = ASM("movq", "$1", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f");
            insts.push_back(ins);
            ins = ASM("", "2", "", "", "label");
        }
        else if(q.op == "&"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("and", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("and", to_string(y) + "(%rbp)", "%rdx");
            }     
        }
        else if(q.op == "|"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("or", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("or", to_string(y) + "(%rbp)", "%rdx");
            }     
        }
        else if(q.op == "^"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("xor", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("xor", to_string(y) + "(%rbp)", "%rdx");
            }
        }
        else if(q.op == "and"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            ins = ASM("cmp", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("je", "1f");
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            ins = ASM("cmp", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("je", "1f");
            insts.push_back(ins);
            ins = ASM("movq", "$1", "%rdx");
            insts.push_back(ins);      
            ins = ASM("jmp", "2f");
            insts.push_back(ins);
            ins = ASM("", "1", "", "", "label");
            insts.push_back(ins);
            ins = ASM("movq", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("", "2", "", "", "label");
        }
        else if(q.op == "or"){
            if(!is_variable(q.arg1)){
                ins = ASM("movq", "$" + q.arg1, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            ins = ASM("cmp", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("jne", "1f");     // true
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            ins = ASM("cmp", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("jne", "1f");     // true
            insts.push_back(ins);
            ins = ASM("movq", "$0", "%rdx");
            insts.push_back(ins);
            ins = ASM("jmp", "2f");     // false
            insts.push_back(ins);
            ins = ASM("", "1", "", "", "label");
            insts.push_back(ins);
            ins = ASM("movq", "$1", "%rdx");
            insts.push_back(ins);
            ins = ASM("", "2", "", "", "label");
        }
        insts.push_back(ins);
        
        ins = ASM("movq", "%rdx", to_string(z) + "(%rbp)");
        insts.push_back(ins);
    }
    else if(q.made_from == quadrup::UNARY){        // b(y) = op a(x)
        //cerr << __func__ << " : Writing asm for unary " << endl;
        if(q.op == "~"){
            if(!is_variable(q.arg2)){
                ins = ASM("movq", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
            }
            insts.push_back(ins);
            ins = ASM("not", "%rdx", "");
        }
        else if(q.op == "not") {
            //cerr << __func__ << " : Generating asm for logical not " << q.arg1 << endl;
            if(!is_variable(q.arg2)) { // Corrected: check q.arg1 instead of q.arg2
                ins = ASM("movq", "$" + q.arg2, "%rdx"); // Move q.arg1 into %rax
            } else {
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx"); // Move q.arg1 into %rax
            }
            insts.push_back(ins);

            
            ins = ASM("cmpq", "$0", "%rdx"); // Compare q.arg1 with 0
            insts.push_back(ins);
            ins = ASM("sete", "%al"); // Set %al to 1 if q.arg1 is 0 (True), else 0 (False)
            insts.push_back(ins);
            ins = ASM("movzbq", "%al", "%rdx"); // Zero-extend %al to %rax (convert bool to 64-bit int)
            insts.push_back(ins);
        }
        else if(q.op == "-"){
            ins = ASM("xor", "%rdx", "%rdx");
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("sub", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("sub", to_string(x) + "(%rbp)", "%rdx");
            }
        }
        else if(q.op == "+"){
            ins = ASM("xor", "%rdx", "%rdx");
            insts.push_back(ins);
            if(!is_variable(q.arg2)){
                ins = ASM("add", "$" + q.arg2, "%rdx");
            }
            else{
                ins = ASM("add", to_string(x) + "(%rbp)", "%rdx");
            }
        }
        insts.push_back(ins);
        
        ins = ASM("movq", "%rdx", to_string(y) + "(%rbp)");
        insts.push_back(ins);
    }
    else if(q.made_from == quadrup::PRINT_STR){
        if(q.arg1[0] == '\"' || q.arg1[0] == '\''){
                ASM ins = ASM("leaq", m[q.arg1] + "(%rip)", "%rdi");
                insts.push_back(ins);
        }
        else {
            ins = ASM("movq", to_string(x) + "(%rbp)", "%rdi");
            insts.push_back(ins);}
        // ins = ASM("movq", "$0, %rax");
        // insts.push_back(ins);
        ins = ASM("call", "puts");
        insts.push_back(ins);
    }
    else if(q.made_from == quadrup::STR_CMP){
        //cerr<<q.arg1<<"  inside strcmp"<<q.arg2<<endl;
        if((q.arg1[0] == '"' || q.arg1[0] == '\'') && (q.arg2[0] == '"' || q.arg2[0] == '\'')){
            ins = ASM("leaq", m[q.arg1] + "(%rip)", "%rdi");
            insts.push_back(ins);
            ins = ASM("leaq", m[q.arg2] + "(%rip)", "%rsi");
            insts.push_back(ins);
        }
        else if(q.arg1[0] == '"' || q.arg1[0] == '\''){
            ins = ASM("leaq", m[q.arg1] + "(%rip)", "%rdi");
            insts.push_back(ins);
            ins = ASM("movq", to_string(y) + "(%rbp)", "%rsi");
            insts.push_back(ins);
        }
        else if(q.arg2[0] == '"' || q.arg2[0] == '\''){
            ins = ASM("movq", to_string(x) + "(%rbp)", "%rdi");
            insts.push_back(ins);
            ins = ASM("leaq", m[q.arg2] + "(%rip)", "%rsi");
            insts.push_back(ins);
        }
        else {
            ins = ASM("movq", to_string(x) + "(%rbp)", "%rdi");
            insts.push_back(ins);
            ins = ASM("movq", to_string(y) + "(%rbp)", "%rsi");
            insts.push_back(ins);
        }
        ins = ASM("call", "strcmp");
        insts.push_back(ins);
    }
    else if(q.made_from == quadrup::ASSIGNMENT){   // b(y) = a(x)
        if(!is_variable(q.arg1)){
            if(q.result[0] == '*') {   // *x = 5
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
                insts.push_back(ins); 
                ins = ASM("movq", to_string(y) + "(%rbp)", "%r12");
                insts.push_back(ins);
                ins = ASM("movq", "$" + q.arg1, "(%r12)");
                insts.push_back(ins);
            }
            else {
                
                ins = ASM("movq", "$" + q.arg1, to_string(y) + "(%rbp)");
                insts.push_back(ins);
            }
        }
        else{
            if(q.result[0] == '*') {   // *x = y
                ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
                insts.push_back(ins); 
                ins = ASM("movq", to_string(y) + "(%rbp)", "%r12");
                insts.push_back(ins);
                ins = ASM("movq", "%rdx", "(%r12)");
                insts.push_back(ins);
            }
            else {
                if(q.arg1[0]== '\"' || q.arg1[0] == '\''){
                    ins = ASM("leaq", m[q.arg1] + "(%rip)", "%rdx");
                    insts.push_back(ins);
                    ins = ASM("movq", "%rdx", to_string(y) + "(%rbp)");
                    insts.push_back(ins);
                }
                else
                {ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
                insts.push_back(ins);            
                ins = ASM("movq", "%rdx", to_string(y) + "(%rbp)");
                insts.push_back(ins);}
            }
        }
    }
    else if(q.made_from == quadrup::CONDITIONAL){  // if_false/if_true(op) a(x) goto y
        if(!is_variable(q.arg1)){
            ins = ASM("movq", "$" + q.arg1, "%rdx");
        }
        else{
            //cerr<<__func__<<" "<<__LINE__<<" : The temporary "<<q.arg1<<" has stack position "<<to_string(x)<<endl;
            ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
        }
        insts.push_back(ins);
        ins = ASM("cmp", "$0", "%rdx");
        insts.push_back(ins);
        
        if(q.op == "IF_FALSE"){
            ins = ASM("je", "L" + to_string(y));
        }
        else if(q.op == "if_true"){
            ins = ASM("jne", "L" + to_string(y));
        }
        insts.push_back(ins);
    } 
    else if(q.made_from == quadrup::GOTO){         // goto (x)
        ins = ASM("jmp", "L" + to_string(x));
        insts.push_back(ins);
    }
    else if(q.made_from == quadrup::STORE){        // *(r(z) + a2) = a1(x)
        if(q.arg1[0] == '\"' || q.arg1[0] == '\''){
            ins =ASM("leaq", m[q.arg1] + "(%rip)", "%rdx");
            insts.push_back(ins);
            ins = ASM("movq", "%rdx", to_string(x) + "(%rbp)");
            insts.push_back(ins);
        }
        if(!is_variable(q.arg1)){
            ins = ASM("movq", "$" + q.arg1, "%rax");
        }
        else{
            ins = ASM("movq", to_string(x) + "(%rbp)", "%rax");
        }
        insts.push_back(ins);
        
        ins = ASM("movq", to_string(z) + "(%rbp)", "%rdx");
        insts.push_back(ins);

        if(q.arg2 == "" || !is_variable(q.arg2)) {
            ins = ASM("movq", "%rax", q.arg2 + "(%rdx)");
            insts.push_back(ins);
        }
        else {
            cout << "Unknown TAC `" << q.code << "`. Error occured!" << endl;
            exit(1);  
        }
    }
    else if(q.made_from == quadrup::LOAD){         // r(z) = *(a1(x) + a2(y))
        ins = ASM("movq", to_string(x) + "(%rbp)", "%rdx");
        insts.push_back(ins);
        //cerr<<__func__<<" "<<__LINE__<<" : The value of x is "<<x<<endl;
        if(q.arg2 == "" || !is_variable(q.arg2)) {
            ins = ASM("movq", q.arg2 + "(%rdx)", "%rdx");
            insts.push_back(ins);
            //cerr<<__func__<<" "<<__LINE__<<" : The value of y is "<<y<<endl;
        }
        else {
            cout << "Unknown TAC `" << q.code << "`. Error occured!" << endl;
            exit(1);
        }

        ins = ASM("movq", "%rdx", to_string(z) + "(%rbp)");
        //cerr<<__func__<<" "<<__LINE__<<" : The value of z is "<<z<<endl;
        insts.push_back(ins);
    }
    else if(q.made_from == quadrup::BEGIN_FUNC) {  // perform callee duties
        if(y == 1) {        // make start label if it is the main function
            //cerr <<__func__<< " : Making main label in the code "<<endl;
            ins = ASM("", "main", "", "", "label");
            insts.push_back(ins);
            //cerr << __func__ << " : The label generated is "<<ins.code<<endl;
        }

        ins = ASM("", function_dedo(q.arg1), "", "", "label");     // add label
        insts.push_back(ins);


        ins = ASM("pushq", "%rbp");             // old base pointer
        insts.push_back(ins);
        ins = ASM("movq", "%rsp", "%rbp");      // shift base pointer to the base of the new activation frame
        insts.push_back(ins);
        ins = ASM("pushq", "%rbx");
        insts.push_back(ins);
        ins = ASM("pushq", "%rdi");
        insts.push_back(ins);
        ins = ASM("pushq", "%rsi");
        insts.push_back(ins);
        ins = ASM("pushq", "%r12");
        insts.push_back(ins);
        ins = ASM("pushq", "%r13");
        insts.push_back(ins);
        ins = ASM("pushq", "%r14");
        insts.push_back(ins);
        ins = ASM("pushq", "%r15");
        insts.push_back(ins);

        // shift stack pointer to make space for locals and temporaries, ignore if no locals/temporaries in function
        if(x > 0) {
            ins = ASM("sub", "$" + to_string(x), "%rsp");
            insts.push_back(ins);
        }
    }
    else if(q.made_from == quadrup::RETURN_NONE ){
        ins = ASM("popq", "%r11");                      // restore old register values
        insts.push_back(ins);
        ins = ASM("popq", "%r10");
        insts.push_back(ins);
        ins = ASM("popq", "%r9");
        insts.push_back(ins);
        ins = ASM("popq", "%r8");
        insts.push_back(ins);
        ins = ASM("popq", "%rdx");
        insts.push_back(ins);
        ins = ASM("popq", "%rcx");
        insts.push_back(ins);
        ins = ASM("popq", "%rax");
        insts.push_back(ins);

    }
    else if(q.made_from == quadrup::RETURN_NONE_calle){
        ins = ASM("add", "$" + to_string(x), "%rsp");   // delete all local and temporary variables
        insts.push_back(ins);
        ins = ASM("popq", "%r15");                      // restore old register values
        insts.push_back(ins);
        ins = ASM("popq", "%r14");
        insts.push_back(ins);
        ins = ASM("popq", "%r13");
        insts.push_back(ins);
        ins = ASM("popq", "%r12");
        insts.push_back(ins);
        ins = ASM("popq", "%rsi");
        insts.push_back(ins);
        ins = ASM("popq", "%rdi");
        insts.push_back(ins);
        ins = ASM("popq", "%rbx");
        insts.push_back(ins);
        ins = ASM("popq", "%rbp");
        insts.push_back(ins);

        ins = ASM("ret");
        insts.push_back(ins);

    }
    else if(q.made_from == quadrup::RETURN) {    // clean up activation record
        if(q.arg1 != "") {      // Load %rax with the return value if non-void function
            if(!is_variable(q.arg1)) {
                ins = ASM("movq", "$" + q.arg1, "%rax");
            }
            else {
                ins = ASM("movq", to_string(y) + "(%rbp)", "%rax");
            }
            insts.push_back(ins);
        }
        
        ins = ASM("add", "$" + to_string(x), "%rsp");   // delete all local and temporary variables
        insts.push_back(ins);
        ins = ASM("popq", "%r15");                      // restore old register values
        insts.push_back(ins);
        ins = ASM("popq", "%r14");
        insts.push_back(ins);
        ins = ASM("popq", "%r13");
        insts.push_back(ins);
        ins = ASM("popq", "%r12");
        insts.push_back(ins);
        ins = ASM("popq", "%rsi");
        insts.push_back(ins);
        ins = ASM("popq", "%rdi");
        insts.push_back(ins);
        ins = ASM("popq", "%rbx");
        insts.push_back(ins);
        ins = ASM("popq", "%rbp");
        insts.push_back(ins);

        ins = ASM("ret");
        insts.push_back(ins);
    }
    else if(q.made_from == quadrup::END_FUNC) {
        if(x == 1) {        // if main function
            ins = ASM("movq", "$60", "%rax");
            insts.push_back(ins);
            ins = ASM("xor", "%rdi", "%rdi");
            insts.push_back(ins);
            ins = ASM("syscall");
            insts.push_back(ins);
        }
        else {              // otherwise we perform usual callee clean up
            // end func cannot return any values    
            ins = ASM("add", "$" + to_string(y), "%rsp");   // delete all local and temporary variables
            insts.push_back(ins);
            ins = ASM("popq", "%r15");                      // restore old register values
            insts.push_back(ins);
            ins = ASM("popq", "%r14");
            insts.push_back(ins);
            ins = ASM("popq", "%r13");
            insts.push_back(ins);
            ins = ASM("popq", "%r12");
            insts.push_back(ins);
            ins = ASM("popq", "%rsi");
            insts.push_back(ins);
            ins = ASM("popq", "%rdi");
            insts.push_back(ins);
            ins = ASM("popq", "%rbx");
            insts.push_back(ins);
            ins = ASM("popq", "%rbp");
            insts.push_back(ins);
            ins = ASM("ret");
            insts.push_back(ins);
        }
    }
    else if(q.made_from == quadrup::STACK_POINTER) {
        // no need to do anything really for x86
    }
    else if(q.made_from == quadrup::FUNC_CALL) {
        if(x == 0) {        // if function is called without any parameters, we have yet to perform caller responsibilities
            //cerr << " : Performing caller duties no arguments" << endl;
            ins = ASM("pushq", "%rax");
            insts.push_back(ins);
            ins = ASM("pushq", "%rcx");
            insts.push_back(ins);
            ins = ASM("pushq", "%rdx");
            insts.push_back(ins);
            ins = ASM("pushq", "%r8");
            insts.push_back(ins);
            ins = ASM("pushq", "%r9");
            insts.push_back(ins);
            ins = ASM("pushq", "%r10");
            insts.push_back(ins);
            ins = ASM("pushq", "%r11");
            insts.push_back(ins);
        }
        ins = ASM("call", this -> function_dedo(q.arg1));      // call the function
        insts.push_back(ins);

        if(this -> function_dedo(q.arg1) == "do_print" ) {          // deal specially with print

        ins = ASM("add", "$8", "%rsp");
        insts.push_back(ins);
        // ins = ASM("popq", "%r11");                      // restore old register values
        // insts.push_back(ins);
        // ins = ASM("popq", "%r10");
        // insts.push_back(ins);
        // ins = ASM("popq", "%r9");
        // insts.push_back(ins);
        // ins = ASM("popq", "%r8");
        // insts.push_back(ins);
        // ins = ASM("popq", "%rdx");
        // insts.push_back(ins);
        // ins = ASM("popq", "%rcx");
        // insts.push_back(ins);
        // ins = ASM("popq", "%rax");
        // insts.push_back(ins);

        }
        else if(this -> function_dedo(q.arg1) == "allocmem") {
            ins = ASM("add", "$8", "%rsp");             // deal specially with allocmem
            insts.push_back(ins);
        }
        else if(x > 0) {  
            ins = ASM("add", "$" + to_string(x*stack_offset), "%rsp");
            insts.push_back(ins);
        }
    }
    else if(q.made_from == quadrup :: RETURN_VAL_STRCMP){
        // ins = ASM("movq", "%rax", "%eax");
        // insts.push_back(ins);
        ins = ASM("movsxd", "%eax" , "%rax");
        insts.push_back(ins);
        ins = ASM("movq", "%rax", to_string(x) + "(%rbp)");
        insts.push_back(ins);
    }
    else if(q.made_from == quadrup::RETURN_VAL) {
        // move the return value stored in %rax to the required location
        if(q.result != "") {      // if the function returns a value
            ins = ASM("mov", "%rax", to_string(x) + "(%rbp)");
            insts.push_back(ins);
        }

        // restore original state of registers
        ins = ASM("popq", "%r11");
        insts.push_back(ins);
        ins = ASM("popq", "%r10");
        insts.push_back(ins);
        ins = ASM("popq", "%r9");
        insts.push_back(ins);
        ins = ASM("popq", "%r8");
        insts.push_back(ins);
        ins = ASM("popq", "%rdx");
        insts.push_back(ins);
        ins = ASM("popq", "%rcx");
        insts.push_back(ins);
        ins = ASM("popq", "%rax");
        insts.push_back(ins);
    }
    else if(q.made_from == quadrup::PUSH_PARAM){   // pushq a(x) || pushq const
        if(y == 1) {        // first parameter, perform caller saved registers
            ins = ASM("pushq", "%rax");
            insts.push_back(ins);
            ins = ASM("pushq", "%rcx");
            insts.push_back(ins);
            ins = ASM("pushq", "%rdx");
            insts.push_back(ins);
            ins = ASM("pushq", "%r8");
            insts.push_back(ins);
            ins = ASM("pushq", "%r9");
            insts.push_back(ins);
            ins = ASM("pushq", "%r10");
            insts.push_back(ins);
            ins = ASM("pushq", "%r11");
            insts.push_back(ins);
        }
        if(!is_variable(q.arg1)) {  // it is just a constant
            ins = ASM("pushq", "$" + q.arg1, "");
            insts.push_back(ins);
        } 
        else if(q.arg1[0] == '\"' || q.arg1[0] == '\'' || (m.find(q.arg1) != m.end())){
            ins = ASM("leaq", m[q.arg1] + "(%rip)", "%rdx");
            insts.push_back(ins);
            ins = ASM("pushq", "%rdx");
            insts.push_back(ins);
        }
        else if (q.arg1[0] == '*' ){  // push_param *a(x)
            ins = ASM("movq", to_string(x) + "(%rbp)", "%r12");
            insts.push_back(ins);
            ins = ASM("pushq", "(%r12)");
            insts.push_back(ins);
        }
        else {
            ins = ASM("pushq", to_string(x) + "(%rbp)"); // load rbp + x
            insts.push_back(ins);    
        }
    }
   
    return insts;
}

// ASM::ASM() {        // initialize the data members
//     code_1.clear();
//     activations.clear();
// }

void ASM::append(ASM ins) {
    this -> code_1 . push_back(ins);
}

void ASM::get_activation_3ac(node *root) {
    vector<quadrup*> activation;

    bool func_started = false;

    for(quadrup *q : root->tac_codes) {
        if(q -> made_from == quadrup::BEGIN_FUNC) {
            func_started = true;
        }

        if(func_started) {
            activation.push_back(q);
        }

        if(q -> made_from == quadrup::END_FUNC) {
            func_started = false;
            if(activation.size()){
                this -> activations.push_back(activation);
                activation.clear();
            }
        }
    }
}

void ASM::global_generation(node *root) {
    // @TODO
    ASM ins;
    ins = ASM(".data", "", "", "", "segment");
    this -> code_1.push_back(ins);

    //cerr<<__func__<<": Generated global data segment"<<endl;
    //handling strings 
    string temp = "str";
    int num = 1;
    for(quadrup *q : root->tac_codes){

        if(q->arg1 != "" && q->arg1[0] == '\"'){
            if(m.find(q->arg1) != m.end()){
                // q->arg1 = m[q->arg1];
            }
            else{
                ins = ASM(temp + to_string(num) +": .asciz", "", q->arg1, "", "ins");
                this -> code_1.push_back(ins);
                m[q->arg1] = temp + to_string(num);
                // q->arg1 = temp + to_string(num);
                num++;
            }
        }
        else if(q->arg1 != "" && q->arg1[0] == '\''){
            q->arg1[0] = '\"';
            q->arg1[q->arg1.size() - 1] = '\"';
            if(m.find(q->arg1) != m.end()){
                // q->arg1 = m[q->arg1];
            }
            else{
                m[q->arg1] = temp + to_string(num);
                // q->arg1[0] = '\"';
                // q->arg1[q->arg1.size() - 1] = '\"';
                ins = ASM(temp + to_string(num) +": .asciz", "", q->arg1, "", "ins");
                this -> code_1.push_back(ins);
                // q->arg1 = temp + to_string(num);
                num++;
            }

        }

        if(q->arg2 != "" && q->arg2[0] == '\"'){
            if(m.find(q->arg2) != m.end()){
                // q->arg2 = m[q->arg2];
            }
            else{
            ins = ASM(temp + to_string(num) +": .asciz", "", q->arg2, "", "ins");
            this -> code_1.push_back(ins);
            m[q->arg2] = temp + to_string(num);
            // q->arg2 = temp + to_string(num);
            num++;
            }
        }
        else if(q->arg2 != "" && q->arg2[0] == '\''){
            if(m.find(q->arg2) != m.end()){
                q->arg2 = m[q->arg2];
            }
            else{
            m[q->arg2] = temp + to_string(num);
            q->arg2[0] = '\"';
            q->arg2[q->arg2.size() - 1] = '\"';
            ins = ASM(temp + to_string(num) +": .asciz", "", q->arg2, "", "ins");
            this -> code_1.push_back(ins);
            // q->arg2 = temp + to_string(num);
            num++;
            }
        }
    }

    //cerr << __func__ << "Strings have been replaced with pointeers"<<endl;
    ins = ASM("integer_format:", ".asciz", "\"%ld\\n\"", "", "ins");
    this -> code_1.push_back(ins);

    //cerr<< __func__ << "Wrote something integer_format" << endl;
    ins = ASM(".global", "main", "", "", "segment");      // define entry point
    this -> code_1.push_back(ins);
}

void ASM::basic_block_generation(vector<quadrup*> BB, ASM* sub_table) {
    //cerr << __func__ << " : Generating basic block" << endl;
    for(quadrup *q : BB) {
        vector<ASM> insts;
        if(q->made_from == quadrup::CONDITIONAL){
            int x = sub_table -> offset_map[q->arg1].offset;
            //cerr << __func__ << " : Generating asm for conditional" << endl;
            int y = q->abs_jump;
            insts = this -> assembly_generation(*q , x, y);
        }
        else if(q -> made_from == quadrup::PRINT_STR){
            int x = sub_table -> offset_map[q->arg1].offset;
            //cerr << __func__ << " : Generating asm for print_str" << endl;
            insts = this -> assembly_generation(*q, x);
        }
        else if(q->made_from == quadrup::GOTO){
            //cerr << __func__ << " : Generating asm for goto" << endl;
            insts = this -> assembly_generation(*q, q->abs_jump);

        }
        else if(q->made_from == quadrup::BINARY){
            //cerr << __func__ << " : Generating asm for binary" << endl;
            int z = sub_table -> offset_map[q->result].offset;
            int x = sub_table -> offset_map[q->arg1].offset;
            int y = sub_table -> offset_map[q->arg2].offset;
            insts = this -> assembly_generation(*q, x, y, z);       
        }
        else if(q->made_from == quadrup::UNARY){    // b(y) = op a(x)
            //cerr << __func__ << " : Generating asm for unary" << endl;
            int y = sub_table -> offset_map[q->result].offset;
            int x = sub_table -> offset_map[q->arg2].offset;
            insts = this -> assembly_generation(*q, x, y);           
        }
        else if(q->made_from == quadrup::ASSIGNMENT){   // b(y) = a(x)
            //cerr << __func__ << " : Generating asm for assignment with code "<< q->code << endl;
            int y = sub_table -> offset_map[q->result].offset;
            if(is_variable(q->result) && q->result[0] == '*') {
                string q_result = (q->result).substr(1);
                y = sub_table -> offset_map[q_result].offset;
            }
            int x = sub_table -> offset_map[q->arg1].offset;
            insts = this -> assembly_generation(*q, x, y);                
        }
        else if(q->made_from == quadrup::STORE){        // *(r(z) + a2) = a1(x)
            //cerr << __func__ << " : Generating asm for store" << endl;
            int x = sub_table -> offset_map[q->arg1].offset;
            int y = sub_table -> offset_map[q->arg2].offset;   // always 0 since q->arg2 contains a constant always
            int z = sub_table -> offset_map[q->result].offset;
            if(is_variable(q->result) && q->result[0] == '*') {  // push_param *x
                string q_result = (q->result).substr(1);  // remove *
                z = sub_table -> offset_map[q_result].offset;
                //cerr<<__func__<<" : The temporary "<<q_result<<" has stack position "<<x<<endl;
            } 
            insts = this -> assembly_generation(*q, x, y, z);
        }
        else if(q->made_from == quadrup::LOAD){         // r(z) = *(a1(x) + a2)
            //cerr<<__func__<<" : Generating asm for load "<<q->code<<endl;
            int x = sub_table -> offset_map[q->arg1].offset;
            if(is_variable(q->arg1) && q->arg1[0] == '*') {  // push_param *x
                string q_arg1 = (q->arg1).substr(1);  // remove *
                x = sub_table -> offset_map[q_arg1].offset;
                //cerr<<__func__<<" : The temporary "<<q_arg1<<" has stack position "<<x<<endl;
            } 
            int y = sub_table -> offset_map[q->arg2].offset; // always 0 since q->arg2 contains a constant always
            int z = sub_table -> offset_map[q->result].offset;

            insts = this -> assembly_generation(*q, x, y, z);
        }
        else if(q->made_from == quadrup::PUSH_PARAM){   // push_param a1(x)
            //cerr << __func__ << " : Generating asm for push_param" << endl;
            int x = sub_table -> offset_map[q->arg1].offset;
            if(is_variable(q->arg1) && q->arg1[0] == '*') {  // push_param *x
                string q_arg1 = (q->arg1).substr(1);  // remove *
                x = sub_table -> offset_map[q_arg1].offset;
            } 
            sub_table -> no_params++;
            insts = this -> assembly_generation(*q, x, sub_table -> no_params);
        }
        else if(q->made_from == quadrup::POP_PARAM){   // r(x) = pop_param
            // no need to do anything really
            //cerr << __func__ << " : Generating asm for pop_param" << endl;
            insts = this -> assembly_generation(*q);
        }
        else if(q->made_from == quadrup::FUNC_CALL) {
            //cerr << __func__ << " : Generating asm for func_call" << endl;
            insts = this -> assembly_generation(*q, sub_table -> no_params);
            

            sub_table -> no_params = 0;          // reset variable
        }
        else if(q->made_from == quadrup::STR_CMP){
            //cerr << __func__ << " : Generating asm for strcmp" << endl;
            int x = sub_table -> offset_map[q->arg1].offset;
            int y = sub_table -> offset_map[q->arg2].offset;
            insts = this -> assembly_generation(*q, x, y);
        }
        else if(q->made_from == quadrup::RETURN_NONE) {
            //cerr << __func__ << " : Generating asm for return_none" << endl;
            insts = this -> assembly_generation(*q);
        }
        else if(q->made_from == quadrup::RETURN_NONE_calle) {
            //cerr << __func__ << " : Generating asm for return_none" << endl;
            insts = this -> assembly_generation(*q, sub_table -> total_space - 8 * stack_offset, sub_table -> offset_map[q->arg1].offset);
        }
        else if(q->made_from == quadrup::RETURN_VAL_STRCMP) {
            //cerr << __func__ << " : Generating asm for return_val_strcmp" << endl;
            insts = this -> assembly_generation(*q, sub_table -> offset_map[q->result].offset);
        }
        else if(q->made_from == quadrup::RETURN_VAL) {
            //cerr << __func__ << " : Generating asm for return_val" << endl;
            insts = this -> assembly_generation(*q, sub_table -> offset_map[q->result].offset);
        }
        else if(q->made_from == quadrup::BEGIN_FUNC) {  // manage callee saved registers
            if(q->arg1 == "main") {
                //cerr << __func__ << " : Generating asm for main func" << endl;
                sub_table -> is_main = true;
            }
            //cerr << __func__ << " : Generating asm for func " <<q->arg1<< endl;
            insts = this -> assembly_generation(*q, sub_table -> total_space - 8 * stack_offset, sub_table -> is_main);        // space of 8 registers is not considered
        }
        else if(q->made_from == quadrup::END_FUNC) {    // clean up activation record
            // ideally only reaches this place in a void function
            //cerr << __func__ << " : Generating asm for enfunc" << endl;
            insts = this -> assembly_generation(*q, sub_table -> is_main, sub_table -> total_space - 8 * stack_offset);
        }
        else if(q->made_from == quadrup::STACK_POINTER) {       // no need to do anything really
            //cerr << __func__ << " : Generating asm for stack pointer" << endl;
        }
        else if(q->made_from == quadrup::RETURN_VAL || q->made_from == quadrup::RETURN_VAL_STRCMP) {
            //cerr << __func__ << " : Generating asm for return_val" << endl;
            insts = this -> assembly_generation(*q, sub_table -> offset_map[q->result].offset);
        }
        else if(q->made_from == quadrup::BEGIN_FUNC) {  // manage callee saved registers
            if(q->arg1 == "main") {
                //cerr << __func__ << " : Generating asm for main func" << endl;
                sub_table -> is_main = true;
            }
            //cerr << __func__ << " : Generating asm for func " <<q->arg1<< endl;
            insts = this -> assembly_generation(*q, sub_table -> total_space - 8 * stack_offset, sub_table -> is_main);        // space of 8 registers is not considered
        }
        else if(q->made_from == quadrup::END_FUNC) {    // clean up activation record
            // ideally only reaches this place in a void function
            //cerr << __func__ << " : Generating asm for enfunc" << endl;
            insts = this -> assembly_generation(*q, sub_table -> is_main, sub_table -> total_space - 8 * stack_offset);
        }
        else if(q->made_from == quadrup::STACK_POINTER) {       // no need to do anything really
            //cerr << __func__ << " : Generating asm for stack pointer" << endl;
            insts = this -> assembly_generation(*q);
        }
        else if(q->made_from == quadrup::RETURN) {     // clean up activation record
            //cerr << __func__ << " : Generating asm for return" << endl;
            insts = this -> assembly_generation(*q, sub_table -> total_space - 8 * stack_offset, sub_table -> offset_map[q->arg1].offset);
        }
        else{
            //cerr << __func__ << " : Generating asm for bruh moment" << endl;
            insts = this -> assembly_generation(*q);
        }

        // append all the ASMs finally
        for(ASM ins : insts) {
            //cerr << __func__ << " : Appending a large amoun of ASMs " <<__LINE__<< endl;
            this -> append(ins);
        }
    }
}

void ASM::basic_blocks_3ac(vector<quadrup*> activation, ASM* sub_table) {    // generates basic blocks from activations
    set<int> leaders;
    vector<quadrup* > BB;

    int base_offset = activation[0] -> ins_line;
    //cerr<<"ASM:"<< base_offset<<endl;
    for(quadrup *q : activation) {
        //cerr<<"ASM:"<< q -> ins_line<<": "<<q->code<<endl;
    }
    //cerr<<"ASM:"<< "-------------------"<<endl;
    leaders.insert(base_offset);

    for(quadrup *q : activation) {
        if(q -> made_from == quadrup::CONDITIONAL || q -> made_from == quadrup::GOTO) {
            leaders.insert(q -> abs_jump);
            //cerr<<"ASM: "<<q -> abs_jump<<endl;
            leaders.insert(q -> ins_line + 1);
            //cerr<<"ASM: "<<q -> ins_line + 1<<endl;
        }
        else if(q -> made_from == quadrup::FUNC_CALL) {
            leaders.insert(q -> ins_line);
            leaders.insert(q -> ins_line + 1); // call func is made of a singular basic block
        }
        //cerr<<"ASM: "<<"################"<<endl;
    }

    //cerr << __func__ << " : Creating ascending leaders" <<endl;
    vector<int> ascending_leaders;
    for(int leader : leaders) { 
        ascending_leaders.push_back(leader); 
        //cerr<<"ASM : leaders are "<<leader<<endl;
    }
    
    int prev_leader = ascending_leaders[0];
    for(int i = 1; i < ascending_leaders.size(); i++) {
        BB.clear();
        
        for(int j = prev_leader; j < ascending_leaders[i]; j++) {
            BB.push_back(activation[j - base_offset]);
            //cerr << "ASM: "<<j<<" "<<" "<<base_offset<<" "<<j - base_offset<<endl;
        }
        prev_leader = ascending_leaders[i];
        //cerr<<"ASM:"<< BB.size()<<endl;
        this -> basic_block_generation(BB, sub_table);
    }

    BB.clear();
    int final_leader = ascending_leaders[ascending_leaders.size() - 1];
    for(int i = final_leader; i - base_offset < activation.size(); i++) {
        BB.push_back(activation[i - base_offset]);
    }

    this -> basic_block_generation(BB, sub_table);
}


void ASM::text_generation(node *root) {
    ASM ins(".text", "", "", "", "segment");
    this -> code_1.push_back(ins);

    func_name_map["print"] = "do_print";
    func_name_map["allocmem"] = "allocmem";

    this -> get_activation_3ac(root);      // get the activations from entire TAC
    //cerr << __func__ << " : TAC activations generated" << endl;
    for(auto activation : this -> activations) {
        ASM* sub_table = new ASM();
        sub_table -> activation_table_construction(activation);

        //cerr << __func__ <<" : Pushing back to sub tables" << __LINE__<< endl;
        this -> sub_tables.push_back(sub_table);
        this -> basic_blocks_3ac(activation, sub_table);
    }
    //cerr<< __func__ <<" : Text generation complete"<<endl;
}

void ASM::print_code(string asm_file) {
    ofstream out(asm_file);
    
    if(asm_file == "") {
        for(auto ins : this -> code_1) {
            cout << ins.code;
        }
    }
    else {
        for(auto ins : this -> code_1) {
            out << ins.code;
        }
    }

    ifstream print_func("print_func.s");
    string line;

    while(getline(print_func, line)){
        out << line << '\n';
    }

    ifstream alloc_mem("allocmem.s");
    while(getline(alloc_mem, line)) {
        out << line << '\n';
    }
}

ASM::ASM(string name, int offset) {
    this -> name = name;
    this -> offset = offset;
}

bool ASM::is_variable(string s) {   // if the first character is a digit/-/+, then it is a constant and not a variable
    return !(s[0] >= '0' && s[0] <= '9') && (s[0] != '-') && (s[0] != '+');
}

void ASM::activation_table_construction( vector<quadrup*> activation_ins) {
    int pop_cnt = 2;         // 1 8 byte space for the return address + old base pointer
    int local_offset = 8;    // 8 callee saved registers hence, 8 spaces kept free, rsp shall automatically be restored, rbp too
    
    for(quadrup* q : activation_ins) {
        if(q->made_from == quadrup::BEGIN_FUNC || q->made_from == quadrup::STACK_POINTER || q->made_from == quadrup::FUNC_CALL) {   // No nested procedures
            continue; 
        }
         
        if(q->made_from == quadrup::POP_PARAM) {
            this -> offset_map[q->result] = ASM(q->result, stack_offset*pop_cnt);
            //cerr<<__func__<<" "<<__LINE__<<" : Adding an entry for "<<q->result<<" at offset "<< this->offset_map[q->result].offset<<endl;
            pop_cnt++;
        }
        else {
            if(q->made_from == quadrup::CONDITIONAL) {
                if(this -> offset_map.find(q->arg1) == this -> offset_map.end() && is_variable(q->arg1)) {
                    this -> offset_map[q->arg1] = ASM(q->arg1, -stack_offset*local_offset);
                    local_offset++;
                    //cerr<<__func__<<" "<<__LINE__<<" : Adding an entry for "<<q->arg1<<" at offset "<< this->offset_map[q->arg1].offset<<endl;
                }
            }
            else if(q->made_from == quadrup::GOTO){
                continue;
            }
            else {
                if(q->arg1 != "" && q->arg1[0] != '*' && this -> offset_map.find(q->arg1) == this -> offset_map.end() && is_variable(q->arg1)) {

                    this -> offset_map[q->arg1] = ASM(q->arg1, -stack_offset*local_offset);
                    //cerr<<__func__<<" "<<__LINE__<<" : Adding an entry for "<<q->arg1<<" at offset "<< this->offset_map[q->arg1].offset<<endl;
                    local_offset++;
                }
                 if(q->arg2 != "" && q->arg2[0] != '*' && this -> offset_map.find(q->arg2) == this -> offset_map.end() && is_variable(q->arg2)) {
                    this -> offset_map[q->arg2] = ASM(q->arg2, -stack_offset*local_offset);
                    //cerr<<__func__<<" "<<__LINE__<<" : Adding an entry for "<<q->arg2<<" at offset "<< this->offset_map[q->arg2].offset<<endl;
                    local_offset++;
                }
                 if(q->result != "" && q->result[0]!= '*' &&this -> offset_map.find(q->result) == this -> offset_map.end() && is_variable(q->result)) {
                    this -> offset_map[q->result] = ASM(q->result, -stack_offset*local_offset);
                    //cerr<<__func__<<" "<<__LINE__<<" : Adding an entry for "<<q->result<<" at offset "<< this->offset_map[q->result].offset<<endl;
                    local_offset++;
                }
            }
        }
    }

    this -> total_space = stack_offset * local_offset;   // total space occupied by callee saved registers + locals + temporaries
}