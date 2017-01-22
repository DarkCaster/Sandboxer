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
#include <sys/ioctl.h>
#include <poll.h>

#define MAXARGLEN 4095
static LogDef logger=NULL;

//config
static uint32_t key;
static char* ctldir;
static int fdi;
static int fdo;

//data exchange buffers
static uint8_t tmp_buf[DATABUFSZ];
static uint8_t data_buf[MSGPLMAXLEN+1];//as precaution

//proto
static void teardown(int code);
static uint8_t arg_is_numeric(const char* arg);
static uint8_t operation_0(void);
static uint8_t operation_1(char* exec);
static uint8_t operation_2(char* param);
static uint8_t operation_1_2(uint8_t op, char* param);
static uint8_t operation_100(uint8_t *child_ec);

/*static size_t bytes_avail(int fd);

static size_t bytes_avail(int fd)
{
    int nbytes=0;
    int ec=ioctl(fd,FIONREAD,&nbytes);
    if(ec<0)
        return 0;
    else
        return (size_t)nbytes;
}*/

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

//opcode 0 - create new session with separate comm. channels
static uint8_t operation_0(void)
{
    CMDHDR cmd;
    cmd.cmd_type=0;
    cmdhdr_write(data_buf,0,cmd);
    log_message(logger,LOG_INFO,"Sending request");
    uint8_t ec=message_send(fdo,tmp_buf,data_buf,0,CMDHDRSZ,key,REQ_TIMEOUT_MS);
    if(ec!=0)
        return ec;
    int32_t cmdlen=0;
    log_message(logger,LOG_INFO,"Reading response");
    ec=message_read(fdi,tmp_buf,data_buf,0,&cmdlen,key,REQ_TIMEOUT_MS);
    if(ec!=0)
        return ec;
    if(cmdhdr_read(data_buf,0).cmd_type!=0)
    {
        log_message(logger,LOG_ERROR,"Wrong responce code received %i",LI(cmdhdr_read(data_buf,0).cmd_type));
        return 1;
    }
    data_buf[cmdlen]='\0';//received string may not contain leading null character
    puts((char*)(data_buf+CMDHDRSZ));
    return 0;
}

//opcode 1 - set executable name
static uint8_t operation_1_2(uint8_t op, char* param)
{
    CMDHDR cmd;
    cmd.cmd_type=op;
    cmdhdr_write(data_buf,0,cmd);
    //append executable name
    int32_t cmdlen=(int32_t)CMDHDRSZ;
    if(param!=NULL)
    {
        strcpy((char*)(data_buf+cmdlen),param);
        cmdlen+=(int32_t)strlen(param);
    }
    log_message(logger,LOG_INFO,"Sending request");
    uint8_t ec=message_send(fdo,tmp_buf,data_buf,0,cmdlen,key,REQ_TIMEOUT_MS);
    if(ec!=0)
        return ec;
    cmdlen=0;
    log_message(logger,LOG_INFO,"Reading response");
    ec=message_read(fdi,tmp_buf,data_buf,0,&cmdlen,key,REQ_TIMEOUT_MS);
    if(ec!=0)
        return ec;
    //read response
    if(cmdlen!=(int32_t)CMDHDRSZ)
    {
        log_message(logger,LOG_ERROR,"Wrong response length detected!");
        return 1;
    }
    CMDHDR rcmd=cmdhdr_read(data_buf,0);
    if(rcmd.cmd_type!=0)
    {
        log_message(logger,LOG_ERROR,"Executor module reports error while setting exec-name/exec-param!");
        return 2;
    }
    return 0;
}

static uint8_t operation_1(char* exec)
{
    return operation_1_2(1u,exec);
}

static uint8_t operation_2(char* param)
{
    return operation_1_2(2u,param);
}

//launch configured binary
static uint8_t operation_100(uint8_t* child_ec)
{
    CMDHDR cmd;
    cmd.cmd_type=100;
    cmdhdr_write(data_buf,0,cmd);
    log_message(logger,LOG_INFO,"Sending request");
    uint8_t ec=message_send(fdo,tmp_buf,data_buf,0,CMDHDRSZ,key,REQ_TIMEOUT_MS);
    if(ec!=0)
        return ec;
    int cmdlen=0;
    log_message(logger,LOG_INFO,"Reading response");
    ec=message_read(fdi,tmp_buf,data_buf,0,&cmdlen,key,REQ_TIMEOUT_MS);
    if(ec!=0)
        return ec;
    //decode response
    if(cmdlen!=(int32_t)CMDHDRSZ)
    {
        log_message(logger,LOG_ERROR,"Wrong response length detected!");
        return 1;
    }
    CMDHDR rcmd=cmdhdr_read(data_buf,0);
    if(rcmd.cmd_type!=0)
    {
        log_message(logger,LOG_ERROR,"Executor module reports error while performing child exec, error code=%i",rcmd.cmd_type);
        return 2;
    }

    //main command loop
    log_message(logger,LOG_INFO,"Commander module entering control loop");
    cmd.cmd_type=100;
    while(1)
    {
        //TODO: read input
        int32_t send_data_len=CMDHDRSZ;
        //send input
        cmdhdr_write(data_buf,0,cmd);
        ec=message_send(fdo,tmp_buf,data_buf,0,send_data_len,key,REQ_TIMEOUT_MS);
        if(ec!=0)
            return ec;

        //read stdout, captured by executor module
        int32_t recv_out_data_len=0;
        ec=message_read(fdi,tmp_buf,data_buf,0,&recv_out_data_len,key,REQ_TIMEOUT_MS);
        if(ec!=0)
            return ec;
        recv_out_data_len-=(int32_t)CMDHDRSZ;
        if(recv_out_data_len<0)
        {
            log_message(logger,LOG_ERROR,"Corrupted data received from executor");
            return 2;
        }

        uint8_t rcode=cmdhdr_read(data_buf,0).cmd_type;
        if(rcode==101)
        {
            *child_ec=*(data_buf+CMDHDRSZ);
            log_message(logger,LOG_INFO,"Child exit with code=%i",LI(*child_ec));
            return 0;
        }
        else if(rcode!=100)
        {
            log_message(logger,LOG_ERROR,"Wrong response code received. code=%i",LI(rcode));
            return 1;
        }

        write(STDOUT_FILENO,(void*)(data_buf+CMDHDRSZ),(size_t)recv_out_data_len);

        //read stderr, captured by executor module
        int32_t recv_err_data_len=0;
        ec=message_read(fdi,tmp_buf,data_buf,0,&recv_err_data_len,key,REQ_TIMEOUT_MS);
        if(ec!=0)
            return ec;
        recv_err_data_len-=(int32_t)CMDHDRSZ;
        if(recv_err_data_len<0)
        {
            log_message(logger,LOG_ERROR,"Corrupted data received from executor");
            return 2;
        }

        rcode=cmdhdr_read(data_buf,0).cmd_type;
        if(rcode==101)
        {
            *child_ec=*(data_buf+CMDHDRSZ);
            log_message(logger,LOG_INFO,"Child exit with code=%i",LI(*child_ec));
            return 0;
        }
        else if(rcode!=100)
        {
            log_message(logger,LOG_ERROR,"Wrong response code received. code=%i",LI(rcode));
            return 1;
        }

        write(STDERR_FILENO,(void*)(data_buf+CMDHDRSZ),(size_t)recv_err_data_len);

        if(send_data_len<=(int32_t)CMDHDRSZ && recv_out_data_len<=0 && recv_err_data_len<=0)
            usleep((useconds_t)(DATA_WAIT_TIME_MS*1000));
    }

    return 0;
}

//params: <control-dir> <channel-name> <security-key> <operation-code> [operation param] ...


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
        log_message(logger,LOG_ERROR,"usage: <control-dir> <channel-name> <security-key> <operation-code> [operation param] ...");
        teardown(10);
    }

    if(strnlen(argv[1], MAXARGLEN)>=MAXARGLEN)
    {
        log_message(logger,LOG_ERROR,"<control-dir> param too long. Max characters allowed = %i",LI(MAXARGLEN));
        teardown(11);
    }
    //control-dir
    ctldir=argv[1];

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

    //security key
    if(arg_is_numeric(argv[3]))
        key=(uint32_t)strtol(argv[3], NULL, 10);
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

    char* op_param=NULL;
    if(argc>5)
    {
        size_t op_param_len=strnlen(argv[5],MAXARGLEN);
        if(op_param_len>=MAXARGLEN)
        {
            log_message(logger,LOG_ERROR,"[operation param] param too long. Max characters allowed = %i",LI(MAXARGLEN));
            teardown(16);
        }
        op_param=(char*)safe_alloc(op_param_len+1,1);
        op_param[op_param_len]='\0';
        strncpy(op_param,argv[5],op_param_len);
    }

    log_message(logger,LOG_INFO,"Security key is set to %i",LI(key));
    log_message(logger,LOG_INFO,"Control directory is set to %s",LS(ctldir));
    log_message(logger,LOG_INFO,"Channel name is set to %s|%s",LS(channel_out),LS(channel_in));

    if(chdir(ctldir)!=0)
    {
        log_message(logger,LOG_ERROR,"Error changing dir to %s",LS(ctldir));
        teardown(21);
    }

    fdi=open(channel_in,O_RDWR);
    if(fdi<0)
    {
        log_message(logger,LOG_ERROR,"Error opening communication pipe %s",LS(channel_in));
        teardown(22);
    }

    fdo=open(channel_out,O_RDWR);
    if(fdo<0)
    {
        log_message(logger,LOG_ERROR,"Error opening communication pipe %s",LS(channel_out));
        teardown(22);
    }

    uint8_t err;
    uint8_t child_ec=0;

    switch(op_code)
    {
    case 0:
        err=operation_0();
        break;
    case 1:
        err=operation_1(op_param);
        break;
    case 2:
        err=operation_2(op_param);
        break;
    case 100:
        err=operation_100(&child_ec);
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

    if(op_param!=NULL)
        free(op_param);
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

    teardown(child_ec);
}
