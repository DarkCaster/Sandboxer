#include "config.h"
#include "logger.h"

#include <sys/types.h>
#include <sys/wait.h>

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>

static LogDef logger=NULL;

static void teardown(int code)
{
    if(logger!=NULL)
    {
        uint8_t msg_type=code!=0?LOG_ERROR:LOG_INFO;
        log_message(logger,msg_type,"Performing teardown with exit code %i",LI(code));
        log_deinit(logger);
    }
    exit(code);
}

#define MAXARGLEN 4095

//params: <control dir> <channel-name> <security key> [logfile, none for disable] [term signal] [term signal] [term signal] ...

int main(int argc, char* argv[])
{
    //logger
    logger=log_init();
    log_setlevel(logger,LOG_INFO);
    log_stdout(logger,1u);
    log_headline(logger,"Executor startup");
    log_message(logger,LOG_INFO,"Parsing startup params");

    if(argc<3)
    {
        log_message(logger,LOG_ERROR,"<control-dir> or <channel-name> or <security-key> parameters missing");
        log_message(logger,LOG_ERROR,"usage: <control-dir> <channel-name> <security-key> [logfile, relative to control dir, none to disable] [term signal num] [term signal num] [term signal num] ...");
        teardown(-1);
    }

    if(strnlen(argv[0], MAXARGLEN)>=MAXARGLEN)
    {
        log_message(logger,LOG_ERROR,"<control-dir> param too long. Max characters allowed = %i",LI(MAXARGLEN));
        teardown(-2);
    }
    //control-dir
    const char* ctldir=argv[0];

    if(strnlen(argv[1], MAXARGLEN)>=MAXARGLEN)
    {
        log_message(logger,LOG_ERROR,"<control-dir> param too long. Max characters allowed = %i",LI(MAXARGLEN));
        teardown(-3);
    }
    //channel-name
    const char* channel=argv[1];

    if(strnlen(argv[2], MAXARGLEN)>=MAXARGLEN)
    {
        log_message(logger,LOG_ERROR,"<security-key> param too long. Max characters allowed = %i",LI(MAXARGLEN));
        teardown(-4);
    }
    //security key
    uint32_t seed;
    if (isdigit(argv[2]))
        seed=(uint32_t)strtol(argv[2], NULL, 10);
    else
    {
        log_message(logger,LOG_ERROR,"<security-key> param is incorrect");
        teardown(-5);
    }

    if(argc>3)
    {
        if(strnlen(argv[3], MAXARGLEN)>=MAXARGLEN)
        {
            log_message(logger,LOG_ERROR,"[logfile] param too long. Max characters allowed = %i",LI(MAXARGLEN));
            teardown(-6);
        }
        log_message(logger,LOG_INFO,"Enabling logfile %s",LS(argv[3]));
        log_logfile(logger,argv[3]);
    }

    int sig_count=0;
    int* sig_map=NULL;

    if(argc>4)
    {
        sig_count=argc-4;
        sig_map=(int*)calloc((size_t)sig_count,sizeof(int));
        for(int i=0;i<sig_count;++i)
        {
            if(isdigit(argv[4+i]))
            {
                sig_map[i]=(int)strtol(argv[4+i], NULL, 10);
                if(sig_map[i]==0)
                {
                    log_message(logger,LOG_ERROR,"[term signal num] param is zero");
                    teardown(-7);
                }
                log_message(logger,LOG_INFO,"Signal %i is registered for program termination",LI(sig_map[i]));
            }
            else
            {
                log_message(logger,LOG_ERROR,"[term signal num] param is incorrect");
                teardown(-7);
            }
        }
    }

    if(sig_count==0)
    {
        sig_count=1;
        sig_map=(int*)calloc(1,sizeof(int));
        sig_map[0]=15;
    }

    log_message(logger,LOG_INFO,"Secutity key is set to %i",LI(seed));
    log_message(logger,LOG_INFO,"Control directory is set to %s",LS(ctldir));
    log_message(logger,LOG_INFO,"Channel name is set to %s",LS(channel));

    chdir("/");

    sigset_t set;
    int sig;
    int shutdown=0;

    sigfillset(&set);
    sigprocmask(SIG_BLOCK, &set, NULL);

    while(!shutdown)
    {
        sigwait(&set, &sig);
        log_message(logger,LOG_INFO,"Received signal %i",LI(sig));
        for (int i=0;i<sig_count;++i)
            if (sig_map[i]==sig)
            {
                log_message(logger,LOG_INFO,"Performing termination sequence");
                shutdown=1;
                break;
            }
    }

    free(sig_map);
    teardown(0);
}
