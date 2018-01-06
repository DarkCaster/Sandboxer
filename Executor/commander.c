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
#include <errno.h>
#include <poll.h>
#include <termios.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <sys/ioctl.h>


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

//terminal size update flag
static volatile bool term_size_update_needed;

//detach pending flag
static volatile bool detach_pending;

//proto
static void teardown(int code);
static uint8_t arg_is_numeric(const char* arg);
static uint8_t operation_0(char* channel);
static uint8_t operation_1(char* exec);
static uint8_t operation_2(char* param);
static uint8_t operation_1_2(uint8_t op, char* param);
static uint8_t operation_3(char* name, char* value);
static uint8_t operation_4(char* name);
static uint8_t operation_5(char* s_signal);
static uint8_t operation_6(char* dir);
static uint8_t operation_7(char* child_only_terminate);
static uint8_t operation_8(char* orphans_cleanup);
static uint8_t operation_100_200(uint8_t use_pty, uint8_t* child_ec, uint8_t reconnect, const char *out_filename, const char *err_filename);
static uint8_t operation_101_201(uint8_t use_pty);
static uint8_t operation_240(uint32_t source_checksum);
static uint8_t operation_249(void);
static uint8_t operation_250(void);
static uint8_t operation_253(bool grace_shutdown);
static size_t bytes_avail(int fd);

static void sigwinch_signal_handler(int sig, siginfo_t* info, void* context);
static void sigusr2_signal_handler(int sig, siginfo_t* info, void* context);

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"

static void sigwinch_signal_handler(int sig, siginfo_t* info, void* context)
{
    term_size_update_needed=true;
}

static void sigusr2_signal_handler(int sig, siginfo_t* info, void* context)
{
    detach_pending=true;
}

#pragma GCC diagnostic pop

//params: <control-dir> <channel-name> <security-key> <operation-code> [operation param] ...
int main(int argc, char* argv[])
{
    if(argc<5)
    {
        fputs("some of mandatory parameters missing\n",stderr);
        fputs("usage: <control-dir> <channel-name> <security-key> <operation-code> [operation param1] [operation param2] ...\n",stderr);
        fputs("SOURCE_CHECKSUM for this binary (stdout):\n",stderr);
        fprintf(stdout,"%x\n",SOURCE_CHECKSUM);
        exit(10);
    }

    term_size_update_needed=true;
    detach_pending=false;
    comm_shutdown(0u);
    //logger
    logger=log_init();
    log_setlevel(logger,LOG_INFO);
    log_stdout(logger,2u);
    log_headline(logger,"Commander startup");
    log_message(logger,LOG_INFO,"Parsing startup params");

    //set sigwinch_signal_handler signal
    struct sigaction act[2];
    memset(act,2,sizeof(struct sigaction));

    //termination signals
    act[0].sa_sigaction=&sigwinch_signal_handler;
    act[0].sa_flags=SA_SIGINFO;
    if( sigaction(SIGWINCH, &act[0], NULL) < 0 )
    {
        log_message(logger,LOG_ERROR,"Failed to set SIGWINCH signal handler");
        teardown(9);
    }

    act[1].sa_sigaction=&sigusr2_signal_handler;
    act[1].sa_flags=SA_SIGINFO;
    if( sigaction(SIGUSR2, &act[1], NULL) < 0 )
    {
        log_message(logger,LOG_ERROR,"Failed to set SIGUSR2 signal handler");
        teardown(8);
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

    int p_count=argc-5;
    if(p_count<0)
        p_count=0;
    char* op_param[p_count];

    if(argc>5)
    for(int i=5;i<argc;++i)
    {
        size_t op_param_len=strnlen(argv[i],MAXARGLEN);
        if(op_param_len>=MAXARGLEN)
        {
            log_message(logger,LOG_ERROR,"one of [operation param] is too long. Max characters allowed = %i",LI(MAXARGLEN));
            teardown(16);
        }
        op_param[i-5]=(char*)safe_alloc(op_param_len+1,1);
        op_param[i-5][op_param_len]='\0';
        strncpy(op_param[i-5],argv[i],op_param_len);
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
        if(p_count<1)
            err=operation_0(NULL);
        else
            err=operation_0(op_param[0]);
        break;
    case 1:
        if(p_count<1)
            err=51;
        else
            err=operation_1(op_param[0]);
        break;
    case 2:
        if(p_count<1)
            err=52;
        else
            err=operation_2(op_param[0]);
        break;
    case 3:
        if(p_count<1)
            err=53;
        else if(p_count<2)
            err=operation_3(op_param[0],NULL);
        else
            err=operation_3(op_param[0],op_param[1]);
        break;
    case 4:
        if(p_count<1)
            err=54;
        else
            err=operation_4(op_param[0]);
        break;
    case 5:
        if(p_count<1)
            err=55;
        else
            err=operation_5(op_param[0]);
        break;
    case 6:
        if(p_count<1)
            err=56;
        else
            err=operation_6(op_param[0]);
        break;
    case 7:
        if(p_count<1)
            err=57;
        else
            err=operation_7(op_param[0]);
        break;
    case 8:
        if(p_count<1)
            err=58;
        else
            err=operation_8(op_param[0]);
        break;
    case 100:
        if(p_count<1)
            err=operation_100_200(0,&child_ec,0,NULL,NULL);
        else if(p_count<2)
            err=operation_100_200(0,&child_ec,0,op_param[0],NULL);
        else if(p_count<3)
            err=operation_100_200(0,&child_ec,0,op_param[0],op_param[1]);
        else
            err=59;
        break;
    case 101:
        err=operation_101_201(0);
        break;
    case 102:
        if(p_count<1)
            err=operation_100_200(0,&child_ec,1,NULL,NULL);
        else if(p_count<2)
            err=operation_100_200(0,&child_ec,1,op_param[0],NULL);
        else if(p_count<3)
            err=operation_100_200(0,&child_ec,1,op_param[0],op_param[1]);
        else
            err=60;
        break;
    case 200:
        if(p_count<1)
            err=operation_100_200(1,&child_ec,0,NULL,NULL);
        else if(p_count<3)
            err=operation_100_200(1,&child_ec,0,op_param[0],NULL);
        else
            err=61;
        break;
    case 201:
        err=operation_101_201(1);
        break;
    case 202:
        if(p_count<1)
            err=operation_100_200(1,&child_ec,1,NULL,NULL);
        else if(p_count<2)
            err=operation_100_200(1,&child_ec,1,op_param[0],NULL);
        else
            err=62;
        break;
    case 240:
        err=operation_240(SOURCE_CHECKSUM);
        break;
    case 249:
        err=operation_249();
        break;
    case 250:
        err=operation_250();
        break;
    case 253:
        if(p_count<1)
            err=63;
        else if(!arg_is_numeric(op_param[0]))
            err=64;
        else
            err=operation_253((bool)(int)(strtol(op_param[0], NULL, 10)));
        break;
    default:
        log_message(logger,LOG_ERROR,"Unknown operation code %i",LI(op_code));
        teardown(22);
        break;
    }

    if(err!=0)
    {
       log_message(logger,LOG_ERROR,"Operation %i was failed, err=%i",LI(op_code),LI(err));
       close(fdi);
       close(fdo);
       teardown(30);
    }

    if(close(fdi)!=0)
        log_message(logger,LOG_WARNING,"Error closing communication pipe %s",LS(channel_in));

    if(close(fdo)!=0)
        log_message(logger,LOG_WARNING,"Error closing communication pipe %s",LS(channel_out));

    if(p_count>0)
    {
        for(int i=0;i<p_count;++i)
            free(op_param[i]);
    }

    free(channel_in);
    free(channel_out);

    teardown(child_ec);
}

static size_t bytes_avail(int fd)
{
    int nbytes=0;
    int ec=ioctl(fd,FIONREAD,&nbytes);
    if(ec<0)
        return 0;
    else
        return (size_t)nbytes;
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

//opcode 0 - create new session with separate comm. channels
static uint8_t operation_0(char* channel)
{
    CMDHDR cmd;
    cmd.cmd_type=0;
    cmdhdr_write(data_buf,0,cmd);
    int32_t cmdlen=CMDHDRSZ;
    if(channel!=NULL)
    {
        size_t cl=strlen(channel);
        strncpy((char*)(data_buf+CMDHDRSZ),channel,cl);
        cmdlen+=(int32_t)cl;
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
    if(cmdhdr_read(data_buf,0).cmd_type!=0)
    {
        log_message(logger,LOG_ERROR,"Wrong responce code received %i",LI(cmdhdr_read(data_buf,0).cmd_type));
        return 1;
    }
    data_buf[cmdlen]='\0';//received string may not contain leading null character
    puts((char*)(data_buf+CMDHDRSZ));
    return 0;
}

#define param_send_macro(xlen) \
    { log_message(logger,LOG_INFO,"Sending request"); \
    uint8_t ec=message_send(fdo,tmp_buf,data_buf,0,xlen,key,REQ_TIMEOUT_MS); if(ec!=0) return ec; \
    xlen=0; log_message(logger,LOG_INFO,"Reading response"); \
    ec=message_read(fdi,tmp_buf,data_buf,0,&xlen,key,REQ_TIMEOUT_MS); if(ec!=0) return ec; \
    if(xlen!=(int32_t)CMDHDRSZ) { log_message(logger,LOG_ERROR,"Wrong response length detected!"); return 1; } \
    if(cmdhdr_read(data_buf,0).cmd_type!=0) \
    { log_message(logger,LOG_ERROR,"Executor module reports error while performing operation! error code=%i",LI(cmdhdr_read(data_buf,0).cmd_type)); return 2; } }

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
    param_send_macro(cmdlen);
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

static uint8_t operation_4(char* name)
{
    return operation_1_2(4u,name);
}

static uint8_t operation_6(char* dir)
{
    return operation_1_2(6u,dir);
}

static uint8_t operation_3(char* name, char* value)
{
    CMDHDR cmd;
    cmd.cmd_type=3;
    cmdhdr_write(data_buf,0,cmd);
    int32_t len=(int32_t)CMDHDRSZ;
    uint16_t nl = name==NULL?0:(uint16_t)strlen(name);
    uint16_t vl = value==NULL?0:(uint16_t)strlen(value);
    u16_write(data_buf,len,nl);
    len+=2;
    u16_write(data_buf,len,vl);
    len+=2;
    if(nl>0)
    {
        strncpy((char*)(data_buf+len),name,nl);
        len+=nl;
    }
    if(vl>0)
    {
        strncpy((char*)(data_buf+len),value,vl);
        len+=vl;
    }
    param_send_macro(len);
    return 0;
}

static uint8_t operation_5(char* s_signal)
{
    if(!arg_is_numeric(s_signal))
    {
        log_message(logger,LOG_ERROR,"Signal argument must be numeric for now");
        return 1;
    }
    uint8_t signal=(uint8_t)strtol(s_signal, NULL, 10);
    CMDHDR cmd;
    cmd.cmd_type=5;
    cmdhdr_write(data_buf,0,cmd);
    int32_t cmdlen=(int32_t)CMDHDRSZ;
    *(data_buf+CMDHDRSZ)=signal;
    ++cmdlen;
    param_send_macro(cmdlen);
    return 0;
}

static uint8_t operation_7(char* child_only_terminate)
{
    if(!arg_is_numeric(child_only_terminate))
    {
        log_message(logger,LOG_ERROR,"Argument must be numeric - 1 or 0");
        return 1;
    }
    uint8_t par=(uint8_t)strtol(child_only_terminate, NULL, 10);
    CMDHDR cmd;
    cmd.cmd_type=7;
    cmdhdr_write(data_buf,0,cmd);
    int32_t cmdlen=(int32_t)CMDHDRSZ;
    *(data_buf+CMDHDRSZ)=par;
    ++cmdlen;
    param_send_macro(cmdlen);
    return 0;
}

static uint8_t operation_8(char* orphans_cleanup)
{
    if(!arg_is_numeric(orphans_cleanup))
    {
        log_message(logger,LOG_ERROR,"Argument must be numeric - 1 or 0");
        return 1;
    }
    uint8_t par=(uint8_t)strtol(orphans_cleanup, NULL, 10);
    CMDHDR cmd;
    cmd.cmd_type=8;
    cmdhdr_write(data_buf,0,cmd);
    int32_t cmdlen=(int32_t)CMDHDRSZ;
    *(data_buf+CMDHDRSZ)=par;
    ++cmdlen;
    param_send_macro(cmdlen);
    return 0;
}

//launch configured binary
static uint8_t operation_101_201(uint8_t use_pty)
{
    CMDHDR cmd;
    cmd.cmd_type=use_pty?201:101;
    cmdhdr_write(data_buf,0,cmd);
    int32_t cmdlen=CMDHDRSZ;
    param_send_macro(cmdlen);
    return 0;
}

static uint8_t operation_249(void)
{
    CMDHDR cmd;
    cmd.cmd_type=249;
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
    int32_t len=(int32_t)cmdlen-(int32_t)CMDHDRSZ;
    if(len!=4)
    {
        log_message(logger,LOG_ERROR,"Wrong length in response detected");
        return 2;
    }
    uint32_t count=u32_read(data_buf,CMDHDRSZ);
    fprintf(stdout,"%u\n",count);
    fflush(stdout);
    return 0;
}

static uint8_t operation_250(void)
{
    CMDHDR cmd;
    cmd.cmd_type=250;
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
    int32_t len=(int32_t)cmdlen-(int32_t)CMDHDRSZ;
    if(len!=4)
    {
        log_message(logger,LOG_ERROR,"Wrong length in response detected");
        return 2;
    }
    uint32_t count=u32_read(data_buf,CMDHDRSZ);
    fprintf(stdout,"%u\n",count);
    fflush(stdout);
    return 0;
}

static uint8_t operation_240(uint32_t source_checksum)
{
    CMDHDR cmd;
    cmd.cmd_type=240;
    cmdhdr_write(data_buf,0,cmd);
    int32_t cmdlen=CMDHDRSZ;
    u32_write(data_buf,cmdlen,source_checksum);
    cmdlen+=4;
    param_send_macro(cmdlen);
    return 0;
}

static uint8_t operation_253(bool grace_shutdown)
{
    CMDHDR cmd;
    cmd.cmd_type=253;
    cmdhdr_write(data_buf,0,cmd);
    int32_t cmdlen=CMDHDRSZ;
    *(data_buf+cmdlen)=(uint8_t)grace_shutdown;
    ++cmdlen;
    param_send_macro(cmdlen);
    return 0;
}

//launch configured binary
static uint8_t operation_100_200(uint8_t use_pty, uint8_t* child_ec, uint8_t reconnect, const char* out_filename, const char* err_filename)
{
    int o_log_fd=-1;
    int e_log_fd=-1;

    if(out_filename!=NULL && strlen(out_filename)>0)
    {
        o_log_fd=open(out_filename,O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
        if(o_log_fd<0)
            log_message(logger,LOG_ERROR,"Failed to open %s file as stdout log, errno=%i",LS(out_filename),LI(errno));
        else
            log_message(logger,LOG_INFO,"Created %s file as stdout log",LS(out_filename));
    }

    if(err_filename!=NULL && strlen(err_filename)>0)
    {
        e_log_fd=open(err_filename,O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
        if(e_log_fd<0)
            log_message(logger,LOG_ERROR,"Failed to open %s file as stderr log, errno=%i",LS(err_filename),LI(errno));
        else
            log_message(logger,LOG_INFO,"Created %s file as stdout log",LS(err_filename));
    }

    CMDHDR cmd;
    cmd.cmd_type=reconnect?(use_pty?255:254):(use_pty?200:100);
    cmdhdr_write(data_buf,0,cmd);
    int32_t cmdlen=CMDHDRSZ;
    param_send_macro(cmdlen);

    //main command loop
    log_message(logger,LOG_INFO,"Commander module entering control loop");
    cmd.cmd_type=150;
    const size_t max_data_req=(size_t)(MSGPLMAXLEN-CMDHDRSZ);
    struct termios term_settings_backup;
    uint8_t ts_is_set=0;
    if(use_pty)
    {
        log_message(logger,LOG_INFO,"Adjusting terminal settings");
        if(tcgetattr(STDOUT_FILENO,&term_settings_backup)!=0)
            log_message(logger,LOG_WARNING,"Failed to read terminal settings, error code=%i",LI(errno));
        else
        {
            struct termios newopts=term_settings_backup;
            newopts.c_cflag = 0;
            newopts.c_iflag = 0;
            newopts.c_oflag = 0;
            newopts.c_lflag = 0;
            if(tcsetattr(STDOUT_FILENO,TCSANOW,&newopts)!=0)
                log_message(logger,LOG_WARNING,"Failed to set terminal settings, error code=%i",LI(errno));
            else
                ts_is_set=1;
        }
    }

    #define restore_terminal \
        { if(ts_is_set) \
              tcsetattr(STDOUT_FILENO,TCSANOW,&term_settings_backup); \
          if(o_log_fd>=0) \
              close(o_log_fd); \
          if(e_log_fd>=0) \
              close(e_log_fd); }

    #define receive_data(data_len,out_fd,log_fd,sout_failed,fout_failed) \
        { data_len=0; \
        uint8_t ecx=message_read(fdi,tmp_buf,data_buf,0,&data_len,key,REQ_TIMEOUT_MS); \
        if(ecx!=0){ restore_terminal; return ecx; } \
        data_len-=(int32_t)CMDHDRSZ; \
        if(data_len<0) \
            { restore_terminal; log_message(logger,LOG_ERROR,"Corrupted data received from executor"); return 2; } \
        if(cmdhdr_read(data_buf,0).cmd_type==151) \
            { restore_terminal; *child_ec=*(data_buf+CMDHDRSZ); log_message(logger,LOG_INFO,"Child exit with code=%i",LI(*child_ec)); return 0; } \
        else if(cmdhdr_read(data_buf,0).cmd_type!=150) \
            { restore_terminal; log_message(logger,LOG_ERROR,"Wrong response code received. code=%i",LI(cmdhdr_read(data_buf,0).cmd_type)); return 1; } \
        if(data_len>0) \
            { if(!sout_failed && write(out_fd,(void*)(data_buf+CMDHDRSZ),(size_t)data_len)!=(ssize_t)data_len) \
                  sout_failed=true; \
              if(log_fd>=0 && !fout_failed) \
                  { if(write(log_fd,(void*)(data_buf+CMDHDRSZ),(size_t)data_len)!=(ssize_t)data_len) fout_failed=true; else fdatasync(log_fd); } } }

    int data_wait_time=DATA_WAIT_TIME_MS_MIN;
    bool stdout_failed=false;
    bool stderr_failed=false;
    bool fileout_failed=false;
    bool fileerr_failed=false;
    while(1)
    {
        //read input
        int32_t send_data_len=CMDHDRSZ;
        bool term_size_updated=false;
        if(term_size_update_needed && use_pty)
        {
            struct winsize term_size;
            term_size_update_needed=false;
            if(ioctl(STDOUT_FILENO,TIOCGWINSZ,&term_size)==0)
            {
                term_size_updated=true;
                u16_write(data_buf,CMDHDRSZ,term_size.ws_col);
                u16_write(data_buf,CMDHDRSZ+2,term_size.ws_row);
                send_data_len+=4;
            }
        }
        else
        {
            size_t avail=bytes_avail(STDIN_FILENO);
            if(avail>0)
            {
                if(avail>max_data_req)
                    avail=max_data_req;
                ssize_t rcount=read(STDIN_FILENO,(void*)(data_buf+CMDHDRSZ),avail);
                if(rcount<0)
                {
                    if(errno!=EINTR)
                    {
                        detach_pending=true;
                        restore_terminal;
                        log_message(logger,LOG_ERROR,"Error while reading stdin");
                    }
                }
                else
                    send_data_len+=(int32_t)rcount;
            }
        }

        //send input
        if(detach_pending)
        {
            CMDHDR dtcmd;
            dtcmd.cmd_type=251;
            cmdhdr_write(data_buf,0,dtcmd);
        }
        else if(term_size_updated)
        {
            CMDHDR tscmd;
            tscmd.cmd_type=252;
            cmdhdr_write(data_buf,0,tscmd);
        }
        else
            cmdhdr_write(data_buf,0,cmd);

        uint8_t ec=message_send(fdo,tmp_buf,data_buf,0,send_data_len,key,REQ_TIMEOUT_MS);
        if(ec!=0)
        {
            restore_terminal;
            return ec;
        }

        if(detach_pending)
        {
            restore_terminal;
            log_message(logger,LOG_INFO,"Performing commander disconnect");
            return 0;
        }

        int32_t recv_out_data_len=0;
        receive_data(recv_out_data_len,STDOUT_FILENO,o_log_fd,stdout_failed,fileout_failed); //read stdout, captured by executor module

        int32_t recv_err_data_len=0;
        if(use_pty)
            recv_err_data_len=recv_out_data_len;
        else
            receive_data(recv_err_data_len,STDERR_FILENO,e_log_fd,stderr_failed,fileerr_failed); //read stderr, captured by executor module

        if(send_data_len<=(int32_t)CMDHDRSZ && recv_out_data_len<=0 && recv_err_data_len<=0)
        {
            if(data_wait_time>0)
            {
                usleep((useconds_t)(data_wait_time*1000));
                data_wait_time*=2;
                if(data_wait_time>DATA_WAIT_TIME_MS_MAX)
                    data_wait_time=DATA_WAIT_TIME_MS_MAX;
            }
            else
                data_wait_time=1;
        }
        else
            data_wait_time=DATA_WAIT_TIME_MS_MIN;
    }
}
