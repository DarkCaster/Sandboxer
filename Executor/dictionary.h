#ifndef DICTIONARY_INCLUDED
#define DICTIONARY_INCLUDED

#include "config.h"

#ifdef HAVE_INTTYPES_H
    #include <inttypes.h>
#else
    #warning "inttypes.h is not available for your platform. Trying stdint.h"
    #ifdef HAVE_STDINT_H
        #include <stdint.h>
    #else
        #error "stdint.h is not available for your platform. You must manually define used types"
    #endif
#endif

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

#ifdef __cplusplus
}
#endif

#endif
