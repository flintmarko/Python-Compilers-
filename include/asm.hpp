#ifndef X86_HPP
#define X86_HPP
#include <bits/stdc++.h>

#include "node.hpp"


using namespace std;

struct ASM{
    string op = "";
    string arg1 = "";
    string arg2 = "";
    string arg3 = "";
    string code = "";
    string ins_type = "";

    ASM();
    ASM(string, string a1 = "", string a2 = "", string a3 = "", string it = "ins");

    string name = "";
    int offset = 0;         // offset from the base pointer in activation

    ASM(string, int);
    // other entries may be added later
    string name_of_activation;
    bool is_main = false;
    map<string, ASM> offset_map;
    int total_space;
    int no_params = 0;

    void activation_table_construction(vector<quadrup*> activation_ins);
    bool is_variable(string s);

    vector< vector<quadrup*> > activations;
    vector<ASM> code_1;
    vector<ASM* > sub_tables;
    // string code;
    
    void append(ASM ins);
    void print_code(string asm_file = "asm_code.s");

    void get_activation_3ac(node * root);
    void basic_blocks_3ac(vector<quadrup*>, ASM*);
    
    string function_dedo(string s);          

    void global_generation(node *root);
    void text_generation(node* root);
    void basic_block_generation(vector<quadrup*> BB, ASM*);
    vector<ASM> assembly_generation(quadrup, int x = 0, int y = 0, int z = 0);
};


#endif