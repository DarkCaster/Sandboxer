#include "config.h"

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
    int* two=(int*)calloc(1,sizeof(int));
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

    log_headline(log,"TEST UTILITY EXIT");
    log_deinit(log);
}
