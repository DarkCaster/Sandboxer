#include "config.h"
#include "logger.h"
#include "executor_worker.h"

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

static uint8_t arg_is_numeric(const char* arg)
{
    size_t len=strnlen(arg,MAXARGLEN);
    for(size_t i=0;i<len;++i)
        if(!isdigit((int)arg[i]))
            return 0;
    return 1;
}

//params: <control dir> <channel-name> <security key> [logfile, none for disable, path relative to control dir] [term signal] [term signal] [term signal] ...

int main(int argc, char* argv[])
{
    //logger
    logger=log_init();
    log_setlevel(logger,LOG_INFO);
    log_stdout(logger,1u);
    log_headline(logger,"Executor startup");
    log_message(logger,LOG_INFO,"Parsing startup params");

    if(argc<4)
    {
        log_message(logger,LOG_ERROR,"<control-dir> or <channel-name> or <security-key> parameters missing");
        log_message(logger,LOG_ERROR,"usage: <control-dir> <channel-name> <security-key> [logfile, relative to control dir, none to disable] [term signal num] [term signal num] [term signal num] ...");
        teardown(10);
    }

    if(strnlen(argv[1], MAXARGLEN)>=MAXARGLEN)
    {
        log_message(logger,LOG_ERROR,"<control-dir> param too long. Max characters allowed = %i",LI(MAXARGLEN));
        teardown(11);
    }
    //control-dir
    const char* ctldir=argv[1];

    if(strnlen(argv[2], MAXARGLEN)>=MAXARGLEN)
    {
        log_message(logger,LOG_ERROR,"<channel-name> param too long. Max characters allowed = %i",LI(MAXARGLEN));
        teardown(12);
    }
    //channel-name
    const char* channel=argv[2];

    if(strnlen(argv[3], MAXARGLEN)>=MAXARGLEN)
    {
        log_message(logger,LOG_ERROR,"<security-key> param too long. Max characters allowed = %i",LI(MAXARGLEN));
        teardown(13);
    }

    //security key
    uint32_t seed;
    if(arg_is_numeric(argv[3]))
        seed=(uint32_t)strtol(argv[3], NULL, 10);
    else
    {
        log_message(logger,LOG_ERROR,"<security-key> param is incorrect");
        teardown(14);
    }

    if(chdir(ctldir)!=0)
    {
        log_message(logger,LOG_ERROR,"Error changing dir to %s",LS(ctldir));
        teardown(20);
    }

    if(argc>4)
    {
        if(strnlen(argv[4], MAXARGLEN)>=MAXARGLEN)
        {
            log_message(logger,LOG_ERROR,"[logfile] param too long. Max characters allowed = %i",LI(MAXARGLEN));
            teardown(15);
        }
        log_message(logger,LOG_INFO,"Enabling logfile %s",LS(argv[4]));
        log_logfile(logger,argv[4]);
    }

    int sig_count=0;
    int* sig_map=NULL;

    if(argc>5)
    {
        sig_count=argc-5;
        sig_map=(int*)calloc((size_t)sig_count,sizeof(int));
        for(int i=0;i<sig_count;++i)
        {
            if(arg_is_numeric(argv[5+i]))
            {
                sig_map[i]=(int)strtol(argv[5+i], NULL, 10);
                if(sig_map[i]==0)
                {
                    log_message(logger,LOG_ERROR,"[term signal num] param is zero");
                    teardown(16);
                }
                log_message(logger,LOG_INFO,"Signal %i is registered for program termination",LI(sig_map[i]));
            }
            else
            {
                log_message(logger,LOG_ERROR,"[term signal num] param is incorrect");
                teardown(17);
            }
        }
    }

    if(sig_count==0)
    {
        sig_count=2;
        sig_map=(int*)calloc(2,sizeof(int));
        sig_map[0]=15;
        sig_map[1]=2;
    }

    log_message(logger,LOG_INFO,"Secutity key is set to %i",LI(seed));
    log_message(logger,LOG_INFO,"Control directory is set to %s",LS(ctldir));
    log_message(logger,LOG_INFO,"Channel name is set to %s",LS(channel));

    if(chdir("/")!=0)
    {
        log_message(logger,LOG_ERROR,"Error changing dir to /");
        teardown(21);
    }

    sigset_t set;
    sigfillset(&set);
    sigprocmask(SIG_BLOCK,&set,NULL);

    while(1)
    {
        WorkerDef main_worker=launch_worker(logger,ctldir,channel,seed);
        if(main_worker==NULL)
        {
            log_message(logger,LOG_ERROR,"Failed to start main worker for %s channel",LS(channel));
            teardown(22);
        }
        int sig;
        sigwait(&set,&sig);
        log_message(logger,LOG_INFO,"Received signal %i",LI(sig));
        for (int i=0;i<sig_count;++i)
            if (sig_map[i]==sig)
            {
                log_message(logger,LOG_INFO,"Performing termination sequence");
                shutdown_worker(main_worker);
                free(sig_map);
                teardown(0);
            }
    }
}
