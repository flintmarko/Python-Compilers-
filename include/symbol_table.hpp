#include <bits/stdc++.h>
#include <cstdint>
using namespace std;

struct symbol_table_generic;                // Main symbol table;
struct symbol_table_entry;                  // Entry struct for symbol table entry



enum entry_type {
    ARRAY,
    CLASS, //
    VARIABLE, 
    FUNCTION, //
    OBJECT, 
    LITERAL, //
    DEFAULT
};

enum data_type {
    INT,
    FLOAT,
    BOOL,
    NONE,
    STRING,
    CLASS_TYPE,
    NOTYPE
};

void check(symbol_table_entry* entry , vector<data_type> param_types);
bool check_data_type(data_type a , data_type b);


struct symbol_table_entry {
    string name = "";
    entry_type type_entry = DEFAULT;
    uint64_t offset = 0;
    uint64_t size = 0;
    uint64_t lineno = 0;
    symbol_table_generic* present_table = NULL;
    
    symbol_table_generic* next_table = NULL;

    bool is_init = false;
    // Variable specific
    data_type type_data = NOTYPE;
    // Array specific
    uint64_t array_dims;
    vector<data_type> array_datatype;       // Size of each dimension MULTIDIMENSIONAL 
   
    // // Class specific
    string class_name;
    // no overlap
    // // Function specific
    // uint64_t num_param;
    // vector<data_type> param_data_types;
    // data_type return_type;

    // TAC
    string base_ptr_3ac = "";                    // Stores the temporary variable storing the base pointer of the entry             

    symbol_table_entry(string name, entry_type type_entry, symbol_table_generic* present_table, symbol_table_generic* next_table , uint64_t lineno){
        this->name =name;
        this->type_entry = type_entry;
        this->present_table = present_table;
        this->next_table = next_table;
        this->lineno = lineno;
    }

    symbol_table_entry(string name, data_type type_data, symbol_table_generic* present_table, uint64_t lineno){
        this->name = name;
        this->type_data = type_data;
        this->present_table = present_table;
        this->lineno =  lineno;
    }
    

};

inline bool check_data_type(data_type a , data_type b){
    if(a==b)return true;
    else if( (a == INT && b == FLOAT) || (a == FLOAT && b == INT) )return true;
    else if( (a == INT && b == BOOL) || (a == BOOL && b == INT) )return true;
    else return false;

}

inline bool check_data_type1(data_type a, data_type b){
    if((a == INT || a == FLOAT || a == BOOL) && (b==INT || b== BOOL)) return true;
    else return false;
}

inline bool check_data_type2(data_type a, data_type b){
    if((a == INT || a == BOOL) && (b == INT || b == BOOL))return true;
    else return false;
}

inline bool check_data_type3(data_type a, data_type b){
    
    if((a == INT || a == FLOAT || a == BOOL) && (b== INT || b== BOOL || b== FLOAT))return true;
    else return false;
}

struct symbol_table_generic {
    
    vector<symbol_table_entry*> entries;
    
    symbol_table_generic* parent_table = NULL;

    bool is_init = false; 
    bool is_printed;
    string name;

    string category; // 'g' for global, 'c' for class, 'f' for function 'o' for other

    uint64_t scope_start_lineno;
    uint64_t scope_end_lineno;
    
    //FUNCTION and CLASS SPECIFIC

    vector<symbol_table_entry*> params;

    
    //FUNCTION TYPE
    data_type return_type;

     
    //CLASS SPECIFIC 
    symbol_table_generic* parent_class = NULL; //when it is inherited 
    bool is_inherited = false;

    // Runtime stuff
    uint64_t size;                      // Size of object, if representing a class

    symbol_table_generic(string name, string category, uint64_t start){
        this->name = name;
        this->category = category;
        this->scope_start_lineno = start; 
        this->parent_table = NULL;
        this->size = 0;
        is_init = false;
        is_printed = false;
    }
    
    int add_entry_constructor(symbol_table_entry* entry){
        if(entry == NULL) {
            return -1;
        }
        entries.push_back(entry);
        return 0;
    }
    int add_entry(symbol_table_entry* entry) {
        if(entry == NULL) {
            return -1;
        }
        for(auto cur_entry : this->entries){
            if(cur_entry->name==entry->name) {
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<entry->lineno<<endl;
                cerr<<"Error: ENTRY ALREADY PRESENT "<< "ENTRY NAME : "<<entry->name<<" SYMBOL TABLE NAME : "<<this->name<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
            }
        }
        entries.push_back(entry);
        return 0;
    }

    int add_params(symbol_table_entry* entry){
        if(entry == NULL) {
            return -1;
        }
        for(auto cur_entry : this->params){
            if(cur_entry->name==entry->name){
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<entry->lineno<<endl;
                cerr<<"Error: ENTRY ALREADY PRESENT IN PARAMETERS "<< "ENTRY NAME : "<<entry->name<<" SYMBOL TABLE NAME : "<<this->name<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
            }
        }
        params.push_back(entry);
        return 0;
    }
   

    // Lookup variable in current scope or parent scopes (does not work for inherited scopes - other function for that)
    symbol_table_entry* lookup_func_no_param(string name){
        for(auto entry : entries){
            if(entry->name == name && entry->type_entry == FUNCTION){
                return entry;
            }
        }
        symbol_table_entry *ret = NULL;
        if(parent_class != NULL){     // lookup in parent class
            ret = parent_class->lookup_func_no_param(name);
        }
        if(ret == NULL &&  parent_table != NULL) {   // lookup in parent context
            ret =  parent_table -> lookup_func_no_param(name);
        }
        return ret;
    }
    symbol_table_entry* lookup_var(string name) { // look for the entry whose name is 'name' 
        for (auto entry : entries) {
            if (entry->name == name) {
                return entry;
            }
        }
        symbol_table_entry *ret = NULL;
        if(parent_class != NULL){     // lookup in parent class
            ret = parent_class->lookup_var(name);
        }
        if(ret == NULL &&  parent_table != NULL) {   // lookup in parent context
            ret =  parent_table -> lookup_var(name);
        }
        return ret;
    }
    
    symbol_table_entry* lookup_obj(string name ) { // look for the entry whose name is 'name' 
        for (auto entry : entries) {
            if (entry->name == name) {
                return entry;
            }
        }
        symbol_table_entry *ret = NULL;
        if(parent_class != NULL){     // lookup in parent class
            ret = parent_class->lookup_obj(name);
        }
        if(ret == NULL &&  parent_table != NULL) {   // lookup in parent context
            ret =  parent_table -> lookup_obj(name);
        }
        return ret;
    }

    symbol_table_entry* lookup_array(string name) { // look for the entry whose name is 'name' 
        for (auto entry : entries) {
            if (entry->name == name) {
                return entry;
            }
        }
        symbol_table_entry *ret = NULL;
        if(parent_class != NULL){     // lookup in parent class
            ret = parent_class->lookup_array(name );
        }
        if(ret == NULL &&  parent_table != NULL) {   // lookup in parent context
            ret =  parent_table -> lookup_array(name);
        }
        return ret;
    }
    // Lookup in current scope or parent scopes (does not work for inherited scopes - other function for that)
    symbol_table_entry* lookup_func(string name, vector<data_type> param_types) { // look for the entry whose name is 'name' 
        

        // cout<<"***** function lookup **** "<<name<<" name of table "<<this->name<<endl;
        
        for (auto entry : entries) {
            //xxx check param_types
            if (entry->name == name && entry->type_entry == FUNCTION) {
                check(entry , param_types);
                return entry;
            }
        }
        
        // cout<<"Did not find in current symbol table "<<parent_table->name<<endl;
        symbol_table_entry *ret = NULL;
        // cout<<"Created ret"<<endl;
        if(parent_class != NULL){     // lookup in parent class
            // cout<<"Lookup up "<<name<<"in parent class "<<parent_class<<endl;
            ret = parent_class -> lookup_func(name, param_types);
        }
        // cout<<"Did not find in parent class, or it does not exist"<<endl;
        if(ret == NULL &&  parent_table != NULL) {   // lookup in parent context
            // cout<<"Lookup up "<<name<<"in parent table "<<parent_table->name<<"of "<<name<<endl;
            ret =  parent_table -> lookup_func(name , param_types);
        }
        // cout<<"Returning from lookup_func"<<endl;
        return ret;
    }

};

inline void check(symbol_table_entry* entry , vector<data_type> param_types){
    // cout<<"INSIDE CHECK FUNCTION : NAME OF THE ENTRY IS "<<entry->name<<" "<<"NUMBER OF PARAM_TYPES "<<param_types.size()<<endl;
    if(entry->name == "print"){
        // cout<<"INSIDE PRINT FUNCTION"<<endl;
        if(param_types.size()==1 && (param_types[0]==INT || param_types[0]== BOOL || param_types[0]== STRING || param_types[0]== FLOAT));
        else {
                cerr<<"************************ ERROR DETECTED ********************************"<<endl;
                cerr<<"Error at line number: "<<entry->lineno<<endl;
                cerr<<"TYPE CHECKING ERROR IN PRINT "<<endl;
                cerr<<"************************************************************************"<<endl;
                exit(1);
        }
        return; 
    }
    if(entry->name == "range"){
        if(param_types.size()==1 && param_types[0]==INT);
        else if(param_types.size()==2 && param_types[0]==INT && param_types[1]==INT);
        else {
            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
            cerr<<"Error at line number: "<<entry->lineno<<endl;
            cerr<<"TYPE CHECKING ERROR IN RANGE "<<endl;
            cerr<<"************************************************************************"<<endl;
            exit(1);
        }
        return; 
    }
    symbol_table_generic * func_symbol_table = entry->next_table;
    vector<data_type> function_param;
    // cout<<"FUNCTION CHECK : datatypes of function in symbol table entry"<<endl;
    // if()
    for(auto s : func_symbol_table->params){
        // cout<<s->type_data<<" ";
        function_param.push_back(s->type_data);
    }
    // cout<<endl;
    // cout<<"FUNCTION CHECK : datatypes of function passed"<<endl;
    // for(auto s : param_types){
    //     cout<<s<<" ";
    // }
    // cout<<endl;
    
    if(function_param.size()!=param_types.size()){
        cerr<<"************************ ERROR DETECTED ********************************"<<endl;
        cerr<<"Error at line number: "<<entry->lineno<<endl;
        cerr<<"Error: TYPE CHECKING ERROR IN PARAMETERS "<< "ENTRY NAME : "<<entry->name<<" SYMBOL TABLE NAME : "<<endl;
        cerr<<"************************************************************************"<<endl;
        exit(1);
        return;
    }
    for(int i=0; i< function_param.size(); i++){
        if(!check_data_type(function_param[i], param_types[i])){
            cerr<<"************************ ERROR DETECTED ********************************"<<endl;
            cerr<<"Error at line number: "<<entry->lineno<<endl;
            cerr<<"Error: TYPE CHECKING ERROR IN PARAMETERS "<< "ENTRY NAME : "<<entry->name<<" SYMBOL TABLE NAME : "<<endl;
            cerr<<"************************************************************************"<<endl;
            exit(1);          
            return;
        }
    }
}


