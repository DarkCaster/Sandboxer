#ifndef DICTIONARY_INCLUDED
#define DICTIONARY_INCLUDED

#include "helper_macro.h"

#ifdef __cplusplus
extern "C" {
#endif

#define MAXKEYLEN 4096

typedef void * DictDef;

//create new dict
DictDef dict_init(void);
//deinit dictionary, you must perform deinit of all data stored inside manually
void dict_deinit(DictDef dict_instance);

//read data pointer, stored with key
uint8_t* dict_get(const DictDef dict_instance, const char *key);
//store (or update) pointer, referenced by key, return OLD data that was replaced (null, if nothing replaced)
uint8_t* dict_set(const DictDef dict_instance, const char *key, uint8_t* data);
//0-no data stored with selected key, !0-there is data associated with selected key
uint8_t dict_check(const DictDef dict_instance, const char* key);
//remove stored data assosiated with selected key, return data that was removed from dict
uint8_t* dict_del(const DictDef dict_instance, const char* key);
//get key\ptr elements count
int32_t dict_count(const DictDef dict_instance);

char** dict_keylist(const DictDef dict_instance);
void dict_keylist_dispose(char** keylist);

#ifdef __cplusplus
}
#endif

#endif
