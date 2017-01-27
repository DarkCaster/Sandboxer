#include "helper_macro.h"
#include "logger.h"

#include <stdlib.h>
#include <stddef.h>
#include <errno.h>
#include <stdio.h>

// test utility to test executor's handling of forked processes and it's termination
int main(void)
{
    pid_t pid=fork();
    if(pid<0)
    {
        perror("fork");
        exit(1);
    }
    if(pid==0)
    {
        LogDef log=log_init();
        log_setlevel(log,LOG_INFO);
        log_stdout(log,1u);
        log_logfile(log,"logfile-fork.txt");
        log_headline(log,"FORK START");

        int msg=0;
        while(1)
        {
            log_message(log,LOG_INFO,"FORK, message #%i",LI(msg));
            ++msg;
            sleep(1);
        }

        log_headline(log,"FORK EXIT");
        log_deinit(log);
        exit(0);
    }

    LogDef log=log_init();
    log_setlevel(log,LOG_INFO);
    log_stdout(log,1u);
    log_logfile(log,"logfile.txt");
    log_headline(log,"TEST UTILITY START");

    for(int i=0;i<5;++i)
    {
        log_message(log,LOG_INFO,"MAIN, message #%i",LI(i));
        sleep(1);
    }

    log_headline(log,"TEST UTILITY EXIT");
    log_deinit(log);
    exit(0);
}
