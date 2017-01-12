#include "dictionary.h"

#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <pthread.h>

static uint8_t crc8_hash(const uint8_t* pcBlock, int32_t len)
{
    uint8_t crc = 0xFF;
    for(int32_t l=0; l<len; ++l)
    {
        crc ^= *pcBlock++;
        for (uint8_t i = 0; i < 8; i++)
            crc = crc & 0x80 ? (uint8_t)((crc << 1) ^ 0x31) : (uint8_t)(crc << 1);
    }
    return crc;
}

#define NList struct strNlist

struct strNlist {
    NList* next;
    char* key;
    uint8_t* data;
};

#define Dict struct strDict

struct strDict {
    NList* hashtab[256];
    pthread_mutex_t global_lock;
};

DictDef dict_init(void)
{
    Dict* result=(Dict*)calloc(1,sizeof(Dict));
    for(int i=0;i<256;++i)
        result->hashtab[i]=NULL;
    pthread_mutex_init(&(result->global_lock),NULL);
    return (DictDef)result;
}

void dict_deinit(DictDef dict_instance)
{
    pthread_mutex_unlock(&(((Dict*)dict_instance)->global_lock));
    pthread_mutex_destroy(&(((Dict*)dict_instance)->global_lock));
    free((Dict*)dict_instance);
}

static void dict_lock(const DictDef dict_instance)
{
    pthread_mutex_lock( &(((Dict*)dict_instance)->global_lock) );
}

static void dict_unlock(const DictDef dict_instance)
{
    pthread_mutex_unlock( &(((Dict*)dict_instance)->global_lock) );
}

static uint8_t* _dict_get(const DictDef dict_instance, const char* key)
{
    uint8_t hash=crc8_hash((const uint8_t*)key,(int32_t)strnlen(key,MAXKEYLEN));
    for(NList* np = ((Dict*)dict_instance)->hashtab[hash]; np != NULL; np = np->next)
        if(strncmp(key, np->key, MAXKEYLEN) == 0)
          return np->data;
    return NULL;
}

//read data pointer, stored with key
uint8_t* dict_get(const DictDef dict_instance, const char* key)
{
    if(key==NULL)
        return NULL;
    dict_lock(dict_instance);
    uint8_t* result;
    result=_dict_get(dict_instance,key);
    dict_unlock(dict_instance);
    return result;
}

static uint8_t* _dict_del(const DictDef dict_instance, const char* key)
{
    uint8_t hash=crc8_hash((const uint8_t*)key,(int32_t)strnlen(key,MAXKEYLEN));
    Dict* const dict=(Dict*)dict_instance;
    NList* prev=NULL;
    NList* cur=dict->hashtab[hash];
    while(cur!=NULL)
    {
        //check match
        if(strncmp(key, cur->key, MAXKEYLEN) == 0)
        {
            if(prev==NULL)
                dict->hashtab[hash]=cur->next;
            else
                prev->next=cur->next;
            uint8_t* result=cur->data;
            free(cur->key);
            free(cur);
            return result;
        }
        prev=cur;
        cur=cur->next;
    }
    return NULL;
}

static void _dict_set(const DictDef dict_instance, const char* key, uint8_t* data)
{
    Dict* const dict=(Dict*)dict_instance;
    uint8_t hash=crc8_hash((const uint8_t*)key,(int32_t)strnlen(key,MAXKEYLEN));
    //create new element
    NList* el=(NList*)calloc(1,sizeof(NList));
    el->data=data;
    size_t len=strnlen(key,MAXKEYLEN);
    el->key=(char*)calloc(1,len+1);
    el->key[len]='\0';//as precaution
    strncpy(el->key,key,len);
    NList* head=dict->hashtab[hash];
    dict->hashtab[hash]=el;
    el->next=head;
}

//store (or update) pointer, referenced by key, return OLD data that was replaced (null, if nothing replaced)
uint8_t* dict_set(const DictDef dict_instance, const char* key, uint8_t *data)
{
    dict_lock(dict_instance);
    uint8_t* result=_dict_del(dict_instance,key);
    _dict_set(dict_instance, key, data);
    dict_unlock(dict_instance);
    return result;
}

//0-no data stored with selected key, !0-there is data associated with selected key
uint8_t dict_check(const DictDef dict_instance, const char *key)
{
    uint8_t result=0u;
    dict_lock(dict_instance);
    uint8_t hash=crc8_hash((const uint8_t*)key,(int32_t)strnlen(key,MAXKEYLEN));
    for(NList* np = ((Dict*)dict_instance)->hashtab[hash]; np != NULL; np = np->next)
        if(strncmp(key, np->key, MAXKEYLEN) == 0)
        {
            result=1u;
            break;
        }
    dict_unlock(dict_instance);
    return result;
}

//remove stored data assosiated with selected key, return data that was removed from dict
uint8_t* dict_del(const DictDef dict_instance, const char* key)
{
    dict_lock(dict_instance);
    uint8_t* result=_dict_del(dict_instance,key);
    dict_unlock(dict_instance);
    return result;
}
