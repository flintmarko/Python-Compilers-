#include <iostream>
#include <fstream>
#include <string> 
#include <vector> 
#include <bits/stdc++.h>
// #include "symbol_table.hpp"
#include "IR.hpp"

using namespace std;



struct node{
    int node_number = 0;            // Number of the node
    string node_name = "";          // Name of the node
    vector<node *> children;        // Vector of pointers to the children of the node
    node *parent = NULL;            // Pointer to the parent node
    bool is_terminal = false;       // True if the node is a terminal
    int num_child = 0;              // Number of children of the node
    bool is_empty = 0;              // Epsilon productions are not assigned a node in ASTs
    string lexeme = "";
    
    string temp_3ac = "";           // Temporary variable for 3AC
    string temp_3ac_2 = "";         // Temporary variable for 3AC
    // For type checking
    bool is_name = 0;               // 1 if the node is a name, 0 otherwise
    vector<string> atom_name;       // Name resolution for atoms
    bool is_func = 0;               // 1 if the node is a function, 0 otherwise
     
    node * atom_test = NULL;        // For atom test
    // Function call
    vector<node *> args;            // Arguments of the function call
    vector<data_type> arg_types;    // Data types of the arguments

    // List
    vector<node *> list;            // List of elements
    vector<data_type> list_types;   // Data types of the elements
    
    // For RHS of array
    vector<data_type> array_types;  

    // Array lookup
    int array_index = 0;
    bool multidimensional_array = 0;
    data_type type_data = NOTYPE;
    entry_type type_entry = DEFAULT;
    symbol_table_entry *entry = NULL;

    unsigned long lineno = 0;

    node(string node_name, bool is_terminal, unsigned long lineno, int node_number){
        this->node_number = node_number;
        this->node_name = node_name;
        // this->parent = parent;
        this->num_child = 0;
        this->is_terminal = is_terminal;
        this->lineno = lineno ;
    }

    node(string node_name, bool is_terminal, bool is_empty, unsigned long lineno, int node_number){
        this->node_number = node_number;
        this->node_name = node_name;
        // this->parent = parent;
        this->num_child = 0;
        this->is_terminal = is_terminal;
        this->is_empty = is_empty;
        this->lineno = lineno;
    }

    node(string node_name, bool is_terminal, string lexeme, int x, unsigned long lineno, int node_number){
        this->node_number = node_number;
        this->node_name = node_name;
        // this->parent = parent;
        this->num_child = 0;
        this->is_terminal = is_terminal;
        if(is_terminal){
            this -> lexeme = lexeme;
        }
        this->lineno = lineno;

    }

    void set_data_type(data_type type){
        this->type_data = type;
    }
    // Implement functions for writing to a dot file
    void print_tree(){
        cout<<(this->node_name)<<"-> ";
        for(auto i: (this->children)){
            cout<<(i->node_name)<<' ';
        }
        cout<<'\n';
        for(auto i: (this->children)){
            i->print_tree();
        }
    }

    void prune_parse_tree() {
        vector<node *> to_delete;
        vector<node *> new_child_list;
        for(node *child : (this->children)){
            child->prune_parse_tree();
            if(child->children.size() == 1) {
                vector<node *> grandchildren = child->children;
                for(node *grandchild : grandchildren) {
                    grandchild->parent = this;
                    new_child_list.push_back(grandchild);
                }
                to_delete.push_back(child);
            }
            else if (!child->is_terminal && child->children.size() == 0) {
                to_delete.push_back(child);
            }
            else {
                new_child_list.push_back(child);
            }
        }
        for(node *child : to_delete) {
            delete child;
        }
        this->children = new_child_list;
    }

    void make_dot(string filename = "parse.gv"){
        int node_num = 0;
        string dot_code = "digraph ast {\n";
        this->add_nodes(node_num, dot_code);
        dot_code += '\n';
        this->add_edges(dot_code);
        dot_code += "}";
        ofstream out(filename);
        out<<dot_code;
        out.close();
    }
    
    void merge_parent_child(){
        vector<node *> to_delete;
        vector<node *> new_child_list;
        for(node *child : (this->children)){
            child->merge_parent_child();
            if(child->node_name== this->node_name) {
                vector<node *> grandchildren = child->children;
                for(node *grandchild : grandchildren) {
                    grandchild->parent = this;
                    new_child_list.push_back(grandchild);
                }
                to_delete.push_back(child);
            }
            else if (!child->is_terminal && child->children.size() == 0) {
                to_delete.push_back(child);
            }
            else {
                new_child_list.push_back(child);
            }
        }
        for(node *child : to_delete) {
            delete child;
        }
        this->children = new_child_list;

    }
    void make_ast_dot(string filename = "ast.gv"){
        int node_num = 0;
        this->prune_parse_tree();
        this->merge_parent_child();
        string dot_code = "digraph ast {\n";
        this->add_nodes(node_num, dot_code);
        dot_code += '\n';
        this->add_edges(dot_code);
        dot_code += "}";
        ofstream out(filename);
        out<<dot_code;
        out.close();
    }

    void add_nodes(int &node_num, string &dot_code){
        node_num++;
        this->node_number = node_num;
        // if(this->is_terminal) dot_code += "node" + to_string(this->node_number) + "[label = \"" + this->node_name + '\n' +this->lexeme + "\"];\n";
        // else dot_code += "node" + to_string(this->node_number) + "[label = \"" + this->node_name + "\"];\n";
        if(this->is_terminal){
                dot_code += "node" + to_string(this->node_number) + "[label = < <b>" + this->node_name + "</b><br/>(" + this->lexeme + ")>, shape = octagon, style = filled, fillcolor = ";
                dot_code += "\"#cee9ff\", color = ";

            // dot_code += "node" + to_string(this->node_number) + "[label = \"" + '\n' + this->node_name + '\n' + '(' + this->lexeme + ')' + "\", shape = rectangle, color = ";
            if(this->node_name == "NAME"){
                dot_code += "blue";
            }else if(this->node_name.substr(0,8) == "OPERATOR"){
                dot_code += "blue";
            }else if(this->node_name.substr(0,7) == "KEYWORD"){
                dot_code += "blue";
            }else if(this->node_name.substr(0,9) == "DELIMITER"){
                dot_code += "blue";
            }else{
                dot_code += "blue";
            }
            dot_code += "];\n";
        }else{
            dot_code += "node" + to_string(this->node_number) + "[label = \"" + this->node_name + "\", shape = rectangle];\n";

            // dot_code += "node" + to_string(this->node_number) + "[label = \"" + this->node_name + "\"];\n";
        }
        //                 
        // else{
        //     // dot_code += "node" + to_string(this->node_number) + "[label = \"" + this->node_name + "\", shape = rectangle];\n";

        //     dot_code += "node" + to_string(this->node_number) + "[label = \"" + this->node_name + "\"];\n";
        // }



        for(auto child : (this->children)){
            child->add_nodes(node_num, dot_code);
        }
    }

    void add_edges(string (&dot_code)){
        for(auto child : (this->children)){
            dot_code += "node" + to_string(this->node_number) + " -> " + "node" + to_string(child->node_number) + ";\n";

            child->add_edges(dot_code);
        }
    }

    // TAC
    vector<quadrup *> tac_codes;

    long long int exp_int_val = 0;
    double exp_float_val = 0.0;
    string exp_str_val = ""; 
    bool exp_bool_val = false;
    bool exp_is_constant = false; 

    string tac_str = "";
};