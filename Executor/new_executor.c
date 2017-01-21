#include "helper_macro.h"
#include "logger.h"
#include "comm_helper.h"
#include "message.h"
#include "cmd_defs.h"

#include <signal.h>
#include <unistd.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>

#include <sys/time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

#define MAXARGLEN 4095
static LogDef logger=NULL;

//config
static uint8_t mode;
static uint32_t key;
static char* ctldir;
static char* channel;
static char* self;

//params to start child
static char** params;
static int params_count;

//exchange data buffers
static uint8_t tmp_buf[DATABUFSZ];
static uint8_t data_buf[MSGPLMAXLEN];
static uint8_t chld_buf[MSGPLMAXLEN];

//shutdown variable
static volatile uint8_t shutdown;

//prototypes
static void teardown(int code);
static uint8_t arg_is_numeric(const char* arg);

static void show_usage(void)
{
    fprintf(stderr,"Error in parameters\n");
    fprintf(stderr,"Usage: <mode 0-master 1-slave> <logfile 0-disable 1-enable> <control dir> <channel-name> <security key>\n");
    exit(1);
}

int main(int argc, char* argv[])
{
    if( argc!=6 || !arg_is_numeric(argv[1]) || !arg_is_numeric(argv[2]) || !arg_is_numeric(argv[5]) || strnlen(argv[3], MAXARGLEN)>=MAXARGLEN || strnlen(argv[4], MAXARGLEN)>=MAXARGLEN)
        show_usage();

    self=argv[0];
    mode=(uint8_t)strtol(argv[1], NULL, 10);
    uint8_t log_file_enable=(uint8_t)strtol(argv[2], NULL, 10);
    ctldir=argv[3];
    channel=argv[4];
    key=(uint32_t)strtol(argv[5], NULL, 10);
    shutdown=0;

    //logger
    logger=log_init();
    log_setlevel(logger,LOG_INFO);
    if(mode==0)
        log_stdout(logger,(uint8_t)(mode!=0?0:1));

    if(chdir("/")!=0 || chdir(ctldir)!=0)
    {
        fprintf(stderr,"Failed to set ctldir");
        exit(2);
    }

    size_t chn_len=strnlen(channel,MAXARGLEN);
    if(log_file_enable)
    {
        char log_file[chn_len+5];
        strncpy(log_file,channel,chn_len);
        strncpy(log_file+chn_len,".log",4);
        log_file[chn_len+4]='\0';
        log_message(logger,LOG_INFO,"Enabling logfile %s",LS(log_file));
        log_logfile(logger,log_file);
    }

    log_headline(logger,"Executor startup");

    log_message(logger,LOG_INFO,"Secutity key is set to %i",LI(key));
    log_message(logger,LOG_INFO,"Control directory is set to %s",LS(ctldir));
    log_message(logger,LOG_INFO,"Channel name is set to %s",LS(channel));

    char filename_in[chn_len+4];
    strncpy(filename_in,channel,chn_len);
    strncpy(filename_in+chn_len,".in",3);
    filename_in[chn_len+3]='\0';

    char filename_out[chn_len+5];
    strncpy(filename_out,channel,chn_len);
    strncpy(filename_out+chn_len,".out",4);
    filename_out[chn_len+4]='\0';

    if(mkfifo(filename_in, 0600)!=0)
    {
        log_message(logger,LOG_ERROR,"Failed to create communication pipe %s",filename_in);
        teardown(20);
    }

    if(mkfifo(filename_out, 0600)!=0)
    {
        log_message(logger,LOG_ERROR,"Failed to create communication pipe %s",filename_out);
        teardown(21);
    }

    params=(char**)safe_alloc(2,sizeof(char*));
    params_count=1;
    params[0]=NULL;
    params[1]=NULL;

    int fdi=open(filename_in,O_RDWR);
    int fdo=open(filename_out,O_RDWR);

    if(fdi<0||fdo<0)
    {
        log_message(logger,LOG_ERROR,"Failed to open %s|%s pipe",LS(filename_in),LS(filename_out));
        teardown(22);
    }

    log_message(logger,LOG_INFO,"Entering command loop, awaiting requests");

    uint8_t phase=0;
    int32_t pl_len=0;

    //TODO: add proper op-time detection

    //TODO: replace "1" with volatile shutdown variable managed by signal handlers
    while(!shutdown)
    {
        if(phase==0)
        {
            int time_limit=WORKER_REACT_TIME_MS;
            uint8_t ec=message_read_header(fdi,tmp_buf,&time_limit);
            if(ec==0)
            {
                pl_len=0;
                phase=1;
            }
            else if(ec!=3 && ec!=255)
            {
                log_message(logger,LOG_ERROR,"Read error on %s pipe",LS(filename_in));
                shutdown=1;
                break;
            }
        }

        if(phase==1)
        {
            int time_limit=WORKER_REACT_TIME_MS;
            uint8_t ec=message_read_and_transform_payload(fdi,tmp_buf,data_buf,0,&pl_len,key,&time_limit);
            if(ec==0)
                phase=2;
            else if(ec!=3 && ec!=255)
            {
                log_message(logger,LOG_ERROR,"Read error on %s pipe",LS(filename_out));
                shutdown=1;
                break;
            }
        }

        if(phase==2)
        {
            //we have read and properly decoded data, so extract "command" and decide what to do next
            CMDHDR cmdhdr=cmdhdr_read(data_buf,0);
            uint8_t err;
            switch(cmdhdr.cmd_type)
            {
            /*case 0:
                err=operation_0(fdo,worker,ctldir,seed);
                break;
            case 1:
                err=operation_1(fdo,worker,seed,(char*)(cmdbuf+CMDHDRSZ),(size_t)pl_len-(size_t)CMDHDRSZ);
                break;
            case 2:
                err=operation_2(fdo,worker,seed,(char*)(cmdbuf+CMDHDRSZ),(size_t)pl_len-(size_t)CMDHDRSZ);
                break;
            case 100:
                err=operation_100_101(fdi,fdo,worker,seed,0);
                break;
            case 101:
                err=operation_100_101(fdi,fdo,worker,seed,1);
                break;*/
            default:
                log_message(logger,LOG_WARNING,"Unknown operation code %i",LI(cmdhdr.cmd_type));
                err=0;
                break;
            }
            if(err!=0)
            {
               if(err!=255)
                   log_message(logger,LOG_ERROR,"Operation %i was failed",LI(cmdhdr.cmd_type));
               shutdown=1;
               break;
            }
            phase=0;
        }
    };

    log_message(logger,LOG_INFO,"Command loop is shutting down");
    if(fdi>=0 && close(fdi)!=0)
        log_message(logger,LOG_ERROR,"Failed to close %s pipe",LS(filename_in));
    if(fdo>=0 && close(fdo)!=0)
        log_message(logger,LOG_ERROR,"Failed to close %s pipe",LS(filename_out));

    int ec=remove(filename_in);
    if(ec!=0)
        log_message(logger,LOG_ERROR,"Failed to remove pipe at %s, ec==%i",LS(filename_in),LI(ec));

    ec=remove(filename_out);
    if(ec!=0)
        log_message(logger,LOG_ERROR,"Failed to remove pipe at %s, ec==%i",LS(filename_out),LI(ec));

    int pos=0;
    while(params[pos]!=NULL)
    {
        free(params[pos]);
        ++pos;
    }
    free(params);

    //TODO: signals handling
    teardown(0);
}

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

static uint8_t arg_is_numeric(const char* arg)
{
    size_t len=strnlen(arg,MAXARGLEN);
    for(size_t i=0;i<len;++i)
        if(!isdigit((int)arg[i]))
            return 0;
    return 1;
}
