#include "helper_macro.h"

#include "dictionary.h"
#include "hash.h"
#include "logger.h"
#include "message.h"

#include <stdlib.h>
#include <stddef.h>

int main(void)
{
    LogDef log=log_init();
    log_setlevel(log,LOG_INFO);
    log_stdout(log,1u);
    log_logfile(log,"logfile.txt");
    int test_val=0;
    log_headline(log,"TEST UTILITY START");
    log_message(log,LOG_INFO,"Test values %i %u %f %c %s %p %p",LI(1),LU(2),LF(3),LC('x'),LS("text"),NULL,&test_val);

    log_headline(log,"DICTIONARY TEST START");
    DictDef dict=dict_init();

    int one=1;
    int* two=(int*)safe_alloc(1,sizeof(int));
    *two=2;
    log_message(log,LOG_INFO,"dict_check should be 0, actual = %i", LI(dict_check(dict,"one")));
    dict_set(dict,"one",(uint8_t*)&one);
    log_message(log,LOG_INFO,"dict_check should be 1, actual = %i", LI(dict_check(dict,"one")));
    int* one_p=(int*)dict_get(dict,"one");
    log_message(log,LOG_INFO,"one addr is %p, one_p addr is %p", &one, one_p);
    log_message(log,LOG_INFO,"dict_check should be 0, actual = %i", LI(dict_check(dict,"two")));
    dict_set(dict,"two",(uint8_t*)two);
    log_message(log,LOG_INFO,"dict_check should be 1, actual = %i", LI(dict_check(dict,"two")));
    dict_set(dict,"three",NULL);
    log_message(log,LOG_INFO,"dict_check should be 1, actual = %i", LI(dict_check(dict,"three")));
    log_message(log,LOG_INFO,"dict_count should be 3, actual = %i", LI(dict_count(dict)));
    int* two_d=(int*)dict_del(dict,"two");
    log_message(log,LOG_INFO,"dict_check should be 0, actual = %i", LI(dict_check(dict,"two")));
    log_message(log,LOG_INFO,"two addr is %p, two_d addr is %p", two, two_d);
    int* null_d=(int*)dict_del(dict,"three");
    log_message(log,LOG_INFO,"dict_check should be 0, actual = %i", LI(dict_check(dict,"three")));
    dict_del(dict,"three");
    log_message(log,LOG_INFO,"dict_check should be 0, actual = %i", LI(dict_check(dict,"three")));
    log_message(log,LOG_INFO,"null_d should be nil, actual is %p", null_d);
    log_message(log,LOG_INFO,"dict_count should be 1, actual = %i", LI(dict_count(dict)));
    dict_del(dict,"one");
    log_message(log,LOG_INFO,"dict_count should be 0, actual = %i", LI(dict_count(dict)));
    dict_del(dict,"one");
    log_message(log,LOG_INFO,"dict_count should be 0, actual = %i", LI(dict_count(dict)));
    free(two);

    dict_set(dict,"one",(uint8_t*)&one);
    log_message(log,LOG_INFO,"dict_count should be 1, actual = %i", LI(dict_count(dict)));
    dict_set(dict,"one",(uint8_t*)&one);
    log_message(log,LOG_INFO,"dict_count should be 1, actual = %i", LI(dict_count(dict)));
    dict_deinit(dict);

    log_headline(log,"HASH TEST START");
    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wpedantic"
    char c0[0];
    #pragma GCC diagnostic pop
    if(0x00000000!=get_hash(0x00000000,(const uint8_t*)c0,0,0))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0x6a396f08!=get_hash(0xFBA4C795,(const uint8_t*)c0,0,0))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0x81f16f39!=get_hash(0xffffffff,(const uint8_t*)c0,0,0))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    uint8_t b1_0[1]={ 0x00 };
    uint8_t b1_f[1]={ 0xff };
    if(0x514e28b7!=get_hash(0x00000000,(const uint8_t*)b1_0,0,1))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0xea3f0b17!=get_hash(0xFBA4C795,(const uint8_t*)b1_0,0,1))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0xfd6cf10d!=get_hash(0x00000000,(const uint8_t*)b1_f,0,1))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    uint8_t b2[2]={ 0x00, 0x11 };
    uint8_t b3[3]={ 0x00, 0x11, 0x22 };
    uint8_t b4[4]={ 0x00, 0x11, 0x22, 0x33 };
    uint8_t b5[5]={ 0x00, 0x11, 0x22, 0x33, 0x44 };
    uint8_t b6[6]={ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55 };
    uint8_t b7[7]={ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66 };
    uint8_t b8[8]={ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77 };
    uint8_t b9[9]={ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 };
    if(0x16c6b7ab!=get_hash(0x00000000,(const uint8_t*)b2,0,2))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0x8eb51c3d!=get_hash(0x00000000,(const uint8_t*)b3,0,3))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0xb4471bf8!=get_hash(0x00000000,(const uint8_t*)b4,0,4))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0xe2301fa8!=get_hash(0x00000000,(const uint8_t*)b5,0,5))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0xfc2e4a15!=get_hash(0x00000000,(const uint8_t*)b6,0,6))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0xb074502c!=get_hash(0x00000000,(const uint8_t*)b7,0,7))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0x8034d2a0!=get_hash(0x00000000,(const uint8_t*)b8,0,8))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0xb4698def!=get_hash(0x00000000,(const uint8_t*)b9,0,9))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0x2E4FF723!=get_hash(0x00000000,(const uint8_t*)"The quick brown fox jumps over the lazy dog",0,43))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0xC09DC139!=get_hash(0x0000029A,(const uint8_t*)"The quick brown fox jumps over the lazy dog",0,43))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0x517F9467!=get_hash(0x51c757e7,(const uint8_t*)"The quick brown fox jumps over the lazy dog",0,43))
        log_message(log,LOG_ERROR,"mmhash test failed!");
    if(0x48B6D83F!=get_hash(0x51c757e7,(const uint8_t*)"The quick brown fox jumps over the lazy cog",0,43))
        log_message(log,LOG_ERROR,"mmhash test failed!");

    log_headline(log,"TEST UTILITY EXIT");
    log_deinit(log);
}
