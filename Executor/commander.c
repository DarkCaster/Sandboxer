#include "helper_macro.h"
#include "logger.h"
#include "cmd_defs.h"
#include "message.h"
#include "comm_helper.h"

#include <sys/types.h>
#include <sys/wait.h>

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <poll.h>

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

static uint8_t operation_0(int fdi, int fdo, uint32_t seed)
{
    uint8_t* tmpbuff=(uint8_t*)safe_alloc(DATABUFSZ,1);
    uint8_t* cmdbuf=(uint8_t*)safe_alloc(DATABUFSZ,1);
    cmdbuf[DATABUFSZ-1]='\0';
    CMDHDR cmd;
    cmd.cmd_type=0;
    cmdhdr_write(cmdbuf,0,cmd);
    int32_t cmdlen=(int32_t)CMDHDRSZ;
    log_message(logger,LOG_INFO,"Sending request");
    uint8_t ec=message_send(fdo,tmpbuff,cmdbuf,0,cmdlen,seed,REQ_TIMEOUT_MS);
    if(ec!=0)
    {
        free(tmpbuff);
        free(cmdbuf);
        return ec;
    }
    cmdlen=0;
    log_message(logger,LOG_INFO,"Reading response");
    ec=message_read(fdi,tmpbuff,cmdbuf,0,&cmdlen,seed,REQ_TIMEOUT_MS);
    if(ec!=0)
    {
        free(tmpbuff);
        free(cmdbuf);
        return ec;
    }
    cmdbuf[cmdlen]='\0';
    free(cmdbuf);
    free(tmpbuff);
    return 0;
}

//params: <control-dir> <channel-name> <security-key> <operation-code> [command] [param1] [param2] ...


int main(int argc, char* argv[])
{
    comm_shutdown(0u);
    //logger
    logger=log_init();
    log_setlevel(logger,LOG_INFO);
    log_stdout(logger,2u);
    log_headline(logger,"Commander startup");
    log_message(logger,LOG_INFO,"Parsing startup params");

    if(argc<5)
    {
        log_message(logger,LOG_ERROR,"<control-dir>, <channel-name>, <security-key> or <operation-code> parameters missing");
        log_message(logger,LOG_ERROR,"usage: <control-dir> <channel-name> <security-key> <operation-code> [command] [param1] [param2] ...");
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
    size_t ch_base_len=strnlen(argv[2],MAXARGLEN);

    char* channel_in=(char*)safe_alloc(ch_base_len+5,1);
    strncpy(channel_in,argv[2],ch_base_len);
    strncpy(channel_in+ch_base_len,".out",4);
    channel_in[ch_base_len+4]='\0';

    char* channel_out=(char*)safe_alloc(ch_base_len+4,1);
    strncpy(channel_out,argv[2],ch_base_len);
    strncpy(channel_out+ch_base_len,".in",3);
    channel_out[ch_base_len+3]='\0';

    if(strnlen(argv[3], MAXARGLEN)>=MAXARGLEN)
    {
        log_message(logger,LOG_ERROR,"<security-key> param too long. Max characters allowed = %i",LI(MAXARGLEN));
        teardown(13);
    }

    uint32_t seed=0;
    //security key
    if(arg_is_numeric(argv[3]))
        seed=(uint32_t)strtol(argv[3], NULL, 10);
    else
    {
        log_message(logger,LOG_ERROR,"<security-key> param is incorrect");
        teardown(14);
    }

    if(!arg_is_numeric(argv[4]))
    {
        log_message(logger,LOG_ERROR,"<operation-code> param must be a number");
        teardown(14);
    }

    uint32_t op_test=(uint32_t)strtol(argv[4], NULL, 10);
    if(op_test>255)
    {
        log_message(logger,LOG_ERROR,"<operation-code> param must be a number between 0 and 255");
        teardown(15);
    }
    uint8_t op_code=(uint8_t)op_test;

    int exec_count=argc-5;

    log_message(logger,LOG_INFO,"Secutity key is set to %i",LI(seed));
    log_message(logger,LOG_INFO,"Control directory is set to %s",LS(ctldir));
    log_message(logger,LOG_INFO,"Channel name is set to %s|%s",LS(channel_out),LS(channel_in));

    if(chdir(ctldir)!=0)
    {
        log_message(logger,LOG_ERROR,"Error changing dir to %s",LS(ctldir));
        teardown(21);
    }

    int fdi=open(channel_in,O_RDWR);
    if(fdi<0)
    {
        log_message(logger,LOG_ERROR,"Error opening communication pipe %s",LS(channel_in));
        teardown(22);
    }

    int fdo=open(channel_out,O_RDWR);
    if(fdo<0)
    {
        log_message(logger,LOG_ERROR,"Error opening communication pipe %s",LS(channel_out));
        teardown(22);
    }

    uint8_t err;
    switch(op_code)
    {
    case 0:
        err=operation_0(fdi,fdo,seed);
        break;
    default:
        log_message(logger,LOG_ERROR,"Unknown operation code %i",LI(op_code));
        teardown(22);
        break;
    }

    if(err!=0)
    {
       log_message(logger,LOG_ERROR,"Operation %i was failed",LI(op_code));
       close(fdi);
       close(fdo);
       teardown(30);
    }

    if(close(fdi)!=0)
        log_message(logger,LOG_WARNING,"Error closing communication pipe %s",LS(channel_in));

    if(close(fdo)!=0)
        log_message(logger,LOG_WARNING,"Error closing communication pipe %s",LS(channel_out));

    free(channel_in);
    free(channel_out);

    //TODO: move signal handling logic to bg thread, when needed
    /*
    sigset_t set;
    sigfillset(&set);
    sigprocmask(SIG_BLOCK,&set,NULL);

    int sig;
    sigwait(&set,&sig);
    log_message(logger,LOG_INFO,"Received signal %i",LI(sig));
    if (sig==15||sig==2)
    {
        log_message(logger,LOG_INFO,"Performing termination sequence");
        teardown(0);
    }*/

    teardown(0);
}
