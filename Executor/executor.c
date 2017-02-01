#include "helper_macro.h"
#include "logger.h"
#include "comm_helper.h"
#include "message.h"
#include "cmd_defs.h"
#include "pid_list.h"

#include <signal.h>
#include <unistd.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>
#include <pty.h>
#include <utmp.h>
#include <dirent.h>

#include <sys/time.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/ioctl.h>

#define MAXARGLEN 4095
static LogDef logger=NULL;

//config
static uint8_t mode;
static uint32_t key;
static uint8_t log_file_enabled;
static char* ctldir;
static char* channel;
static char* self;
static int fdi;
static int fdo;
static bool terminate_orphans;

//params to start child
static char** params;
static int params_count;
static char* workdir;

//child env
static char** child_envset_v;
static char** child_envset_n;
static int child_envset_count;

static char** child_envdel_v;
static int child_envdel_count;

//data exchange buffers
static uint8_t tmp_buf[DATABUFSZ];
static uint8_t data_buf[MSGPLMAXLEN+1];//as precaution
static uint8_t chld_buf[MSGPLMAXLEN+1];

//volatile variables, used for async-signal handling
static volatile uint8_t shutdown;
static volatile uint8_t command_mode;
static volatile uint8_t child_is_alive;
static volatile uint8_t child_ec;
static volatile uint8_t child_signal_set;
static volatile int child_signal;

//pid management stuff
static pthread_mutex_t pid_mutex;
static void pid_lock(void);
static void pid_unlock(void);
static PidListDef _slave_list; //meant only to be accesed within pid_lock\pid_unlock

//filename for control channel
char filename_in[MAXARGLEN+5];
char filename_out[MAXARGLEN+5];

//other prototypes
// "_" prefix means, that function meant to be executed within pid_lock\pid_unlock because it may be called by signal handlers

static void teardown(int code);
static uint8_t arg_is_numeric(const char* arg);
static void _request_shutdown(void);
static void termination_signal_handler(int sig, siginfo_t* info, void* context);
static void slave_sigchld_signal_handler(int sig, siginfo_t* info, void* context);
static void _slave_terminate_child(int custom_signal);
static PidListDef _create_orphans_list(void);
static void _master_terminate_slaves(int signal);
static void _master_terminate_orphans(int signal);
static int _master_get_slave_count(void);
static int _master_get_orphans_count(void);
static uint8_t request_child_shutdown(bool grace_shutdown, bool skip_responce);
static uint8_t operation_status(uint8_t ec);
static uint8_t operation_0(char* channel_name, size_t len);
static uint8_t operation_1(char* exec, size_t len);
static uint8_t operation_2(char* param, size_t len);
static uint8_t operation_3(char* name, size_t n_len, char* value, size_t v_len);
static uint8_t operation_4(char* name, size_t n_len);
static uint8_t operation_5(uint8_t signal);
static uint8_t operation_6(char* dir, size_t len);
static uint8_t operation_250(void);
static uint8_t operation_253(bool grace_shutdown);
static uint8_t operation_100_101_200_201(uint8_t comm_detached, uint8_t use_pty);

static void show_usage(void)
{
    fprintf(stderr,"Error in parameters\n");
    fprintf(stderr,"Usage: <mode 0-master 1-slave> <logfile 0-disable 1-enable> <control dir> <channel-name> <security key>\n");
    exit(1);
}

static void _slave_terminate_child(int custom_signal)
{
    int signal=custom_signal>0?custom_signal:child_signal;
    PidListDef child_list=pid_list_init();
    if(!populate_list_with_session_members(child_list,getsid(0)))
    {
        log_message(logger,LOG_ERROR,"Failed to populate session pid list. errno=%i",LI(errno));
        pid_list_deinit(child_list);
        return;
    }
    pid_list_remove(child_list,getpid());
    log_message(logger,LOG_INFO,"Found %i pids for current session",LI(pid_list_count(child_list)));
    if(!pid_list_signal(child_list,signal))
        log_message(logger,LOG_WARNING,"Failed to send signal %i to some pids from child list",LI(signal));
    else
        log_message(logger,LOG_INFO,"Signal %i was sent to all childs from the list",LI(signal));
    pid_list_deinit(child_list);
    if(command_mode)
        _request_shutdown();
}

static void _master_terminate_slaves(int signal)
{
    log_message(logger,LOG_INFO,"Sending %i signal to all slave executors",LI(signal));
    pid_list_validate_slave_executors(_slave_list,getpid());
    pid_list_remove(_slave_list,getpid());
    if(!pid_list_signal(_slave_list,signal))
        log_message(logger,LOG_WARNING,"Failed to send %i to some of slaves",LI(signal));
}

static int _master_get_slave_count(void)
{
    pid_list_validate_slave_executors(_slave_list,getpid());
    return pid_list_count(_slave_list);
}

static PidListDef _create_orphans_list(void)
{
    pid_list_validate_slave_executors(_slave_list,getpid());
    PidListDef ignore_list=pid_list_init();
    pid_list_copy_2(_slave_list,ignore_list);
    pid_list_add(ignore_list,getpid());
    PidListDef orphans_list=pid_list_init();
    if(!populate_list_with_orphans(orphans_list,ignore_list))
        log_message(logger,LOG_ERROR,"_create_orphans_list:populate_list_with_orphans failed! errno=",LI(errno));
    pid_list_deinit(ignore_list);
    return orphans_list;
}

static void _master_terminate_orphans(int signal)
{
    PidListDef orphans_list=_create_orphans_list();
    log_message(logger,LOG_INFO,"Found %i orphan pids",LI(pid_list_count(orphans_list)));
    if(!pid_list_signal(orphans_list,signal))
        log_message(logger,LOG_WARNING,"Failed to send signal %i to some pids from orphans list",LI(signal));
    else
        log_message(logger,LOG_INFO,"Signal %i was sent to all childs from the orphans list",LI(signal));
    pid_list_deinit(orphans_list);
}

static int _master_get_orphans_count(void)
{
    PidListDef orphans_list=_create_orphans_list();
    int count=pid_list_count(orphans_list);
    pid_list_deinit(orphans_list);
    return count;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"

static void termination_signal_handler(int sig, siginfo_t* info, void* context)
{
    log_message(logger,LOG_INFO,"Received termination signal %i",LI(sig));
    if(sig==SIGHUP)
    {
        log_message(logger,LOG_INFO,"Ignoring SIGHUP signal");
        return;
    }

    pid_lock();

    if(sig==SIGUSR1 && mode==0)
    {
        _master_terminate_slaves(SIGUSR1);
        _request_shutdown();
    }

    if(sig==SIGUSR1 && mode==1)
        _slave_terminate_child(SIGKILL);

    if(sig==SIGTERM || sig==SIGINT)
    {
        if(mode==0)
        {
            _master_terminate_slaves(SIGTERM);
            _request_shutdown();
        }
        else
            _slave_terminate_child(0);
    }

    pid_unlock();
}

static void slave_sigchld_signal_handler(int sig, siginfo_t* info, void* context)
{
    pid_lock();
    child_is_alive=0u;
    child_ec=(uint8_t)(info->si_status);
    id_t ch_pid=(id_t)(info->si_pid);
    siginfo_t siginfo;
    if(waitid(P_PID,ch_pid,&siginfo,WEXITED|WNOHANG)!=0)
        log_message(logger,LOG_ERROR,"waitid failed! errno=%i",LI(errno));
    else
        log_message(logger,LOG_INFO,"Child process was exit with code %i",LI(child_ec));
    pid_unlock();
}

#pragma GCC diagnostic pop

//request shutdown, delete comm-channel pipes (so no new connection to it can be made).
//and if executor in command_mode mode, current connection also cut down
static void _request_shutdown(void)
{
    if(command_mode)
    {
        comm_shutdown(1);
        if(fdi>0 && close(fdi)!=0)
            log_message(logger,LOG_ERROR,"Failed to close %s pipe",LS(filename_in));
        else
            fdi=0;

        if(fdo>0 && close(fdo)!=0)
            log_message(logger,LOG_ERROR,"Failed to close %s pipe",LS(filename_out));
        else
            fdo=0;
    }
    shutdown=1;
}

int main(int argc, char* argv[])
{
    if( argc!=6 || !arg_is_numeric(argv[1]) || !arg_is_numeric(argv[2]) || !arg_is_numeric(argv[5]) || strnlen(argv[3], MAXARGLEN)>=MAXARGLEN || strnlen(argv[4], MAXARGLEN)>=MAXARGLEN)
        show_usage();

    //set config from params
    self=argv[0];
    mode=(uint8_t)strtol(argv[1], NULL, 10); if(mode>1) mode=1;
    log_file_enabled=(uint8_t)strtol(argv[2], NULL, 10);
    ctldir=argv[3];
    channel=argv[4];
    key=(uint32_t)strtol(argv[5], NULL, 10);

    //set status params
    if(getppid()==1 && mode==0)
        terminate_orphans=true;
    else
        terminate_orphans=false;
    pthread_mutex_init(&pid_mutex,NULL);
    shutdown=0;
    command_mode=1; //until we attempt to launch user binary, this flag is set.
    child_is_alive=0;
    child_ec=0;
    child_signal_set=0;
    child_signal=15;

    workdir=NULL;

    params=(char**)safe_alloc(2,sizeof(char*));
    params_count=1;
    params[0]=NULL;
    params[1]=NULL;

    child_envset_v=NULL;
    child_envset_n=NULL;
    child_envset_count=0;

    child_envdel_v=NULL;
    child_envdel_count=0;

    pid_lock();
    //set pid management parameters and stuff
    if(mode==0)
        _slave_list=pid_list_init();
    else
        _slave_list=NULL;
    pid_unlock();

    //logger
    logger=log_init();
    log_setlevel(logger,LOG_INFO);
    if(mode==0)
        log_stdout(logger,1);
    else
        log_stdout(logger,0);

    struct sigaction act[2];
    memset(act,2,sizeof(struct sigaction));

    //termination signals
    act[0].sa_sigaction=&termination_signal_handler;
    act[0].sa_flags=SA_SIGINFO;
    if( sigaction(SIGTERM, &act[0], NULL) < 0 || sigaction(SIGINT, &act[0], NULL) < 0 || sigaction(SIGHUP, &act[0], NULL) < 0 || sigaction(SIGUSR1, &act[0], NULL) < 0 )
    {
        log_message(logger,LOG_ERROR,"Failed to set one of termination signals handler");
        return 1;
    }

    if(mode==1)
    {
        act[1].sa_sigaction=&slave_sigchld_signal_handler;
        act[1].sa_flags=SA_SIGINFO;
        if(sigaction(SIGCHLD, &act[1], NULL) < 0)
        {
            log_message(logger,LOG_ERROR,"Failed to set SIGCHLD handler for slave");
            return 1;
        }
    }

    if(mode==0)
    {
        act[1].sa_handler=SIG_IGN;
        act[1].sa_flags=0;
        if(sigaction(SIGCHLD,&act[1],NULL) < 0)
        {
            log_message(logger,LOG_ERROR,"Failed to set SIGCHLD handler for master to SIG_IGN");
            return 1;
        }
    }

    if(chdir("/")!=0 || chdir(ctldir)!=0)
    {
        fprintf(stderr,"Failed to set ctldir");
        exit(2);
    }

    size_t chn_len=strnlen(channel,MAXARGLEN);
    if(log_file_enabled!=0)
    {
        char log_file[chn_len+5];
        strncpy(log_file,channel,chn_len);
        strncpy(log_file+chn_len,".log",4);
        log_file[chn_len+4]='\0';
        log_message(logger,LOG_INFO,"Enabling logfile %s",LS(log_file));
        log_logfile(logger,log_file);
    }

    if(mode==0)
        log_message(logger,LOG_INFO,"Executor startup, master mode");
    else
        log_message(logger,LOG_INFO,"Executor startup, slave mode");

    if(terminate_orphans)
        log_message(logger,LOG_WARNING,"Terminate orphans option is active. It is intended to work only in pid-namespace mode, and may lead to undesirable consequences otherwise!");

    log_message(logger,LOG_INFO,"Security key is set to %i",LI(key));
    log_message(logger,LOG_INFO,"Control directory is set to %s",LS(ctldir));
    log_message(logger,LOG_INFO,"Channel name is set to %s",LS(channel));

    strncpy(filename_in,channel,chn_len);
    strncpy(filename_in+chn_len,".in",3);
    filename_in[chn_len+3]='\0';

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

    fdi=open(filename_in,O_RDWR);
    fdo=open(filename_out,O_RDWR);

    if(fdi<0||fdo<0)
    {
        log_message(logger,LOG_ERROR,"Failed to open %s|%s pipe",LS(filename_in),LS(filename_out));
        teardown(22);
    }

    log_message(logger,LOG_INFO,"Entering command loop, awaiting requests");

    uint8_t phase=0;
    int32_t pl_len=0;
    uint32_t idle_time=0;

    //TODO: add proper operation time detection
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
                idle_time=0;
            }
            else if(ec!=3 && ec!=255)
            {
                log_message(logger,LOG_ERROR,"Read error on %s pipe (phase 0). ec=%i",LS(filename_in),LI(ec));
                shutdown=1;
                break;
            }
            else
                idle_time+=WORKER_REACT_TIME_MS;
        }

        if(phase==1)
        {
            int time_limit=WORKER_REACT_TIME_MS;
            uint8_t ec=message_read_and_transform_payload(fdi,tmp_buf,data_buf,0,&pl_len,key,&time_limit);
            if(ec==0)
            {
                phase=2;
                idle_time=0;
            }
            else if(ec!=3 && ec!=255)
            {
                log_message(logger,LOG_ERROR,"Read error on %s pipe (phase 1). ec=%i",LS(filename_out),LI(ec));
                shutdown=1;
                break;
            }
            else
                idle_time+=WORKER_REACT_TIME_MS;
        }

        if(phase==2)
        {
            //we have read and properly decoded data, so extract "command" and decide what to do next
            CMDHDR cmdhdr=cmdhdr_read(data_buf,0);
            uint8_t err;
            switch(cmdhdr.cmd_type)
            {
            case 0:
                err=operation_0((char*)(data_buf+CMDHDRSZ),(size_t)pl_len-(size_t)CMDHDRSZ);
                break;
            case 1:
                err=operation_1((char*)(data_buf+CMDHDRSZ),(size_t)pl_len-(size_t)CMDHDRSZ);
                break;
            case 2:
                err=operation_2((char*)(data_buf+CMDHDRSZ),(size_t)pl_len-(size_t)CMDHDRSZ);
                break;
            case 3:
                if(pl_len<(int32_t)(CMDHDRSZ+4))
                    err=10;
                else
                {
                    int32_t o3_pl_len=(int32_t)pl_len-(int32_t)CMDHDRSZ-4;
                    uint16_t nl=u16_read(data_buf,CMDHDRSZ);
                    uint16_t vl=u16_read(data_buf,CMDHDRSZ+2);
                    if(o3_pl_len<(nl+vl))
                        err=11;
                    else
                        err=operation_3((char*)(data_buf+CMDHDRSZ+4),nl,(char*)(data_buf+CMDHDRSZ+4+nl),vl);
                }
                break;
            case 4:
                err=operation_4((char*)(data_buf+CMDHDRSZ),(size_t)pl_len-(size_t)CMDHDRSZ);
                break;
            case 5:
                if((size_t)pl_len-(size_t)CMDHDRSZ==1)
                    err=operation_5(*(data_buf+(int)CMDHDRSZ));
                else
                    err=12;
                break;
            case 6:
                err=operation_6((char*)(data_buf+CMDHDRSZ),(size_t)pl_len-(size_t)CMDHDRSZ);
                break;
            case 100:
                err=operation_100_101_200_201(0,0);
                break;
            case 101:
                err=operation_100_101_200_201(1,0);
                break;
            case 200:
                err=operation_100_101_200_201(0,1);
                break;
            case 201:
                err=operation_100_101_200_201(1,1);
                break;
            case 250:
                err=operation_250();
                break;
            case 253:
                if((size_t)pl_len-(size_t)CMDHDRSZ==1)
                {
                    bool grace_shutdown=(bool)(*(data_buf+CMDHDRSZ));
                    err=operation_253(grace_shutdown);
                    if( (err==0 && !grace_shutdown) || (err==0 && mode==1) )
                    {
                        pid_lock();
                        _request_shutdown();
                        pid_unlock();
                    }
                }
                else
                    err=13;
                break;
            default:
                log_message(logger,LOG_WARNING,"Unknown operation code %i",LI(cmdhdr.cmd_type));
                err=0;
                break;
            }
            if(err!=0)
            {
               if(err!=255)
               {
                   log_message(logger,LOG_ERROR,"Operation %i was failed with ec %i",LI(cmdhdr.cmd_type),LI(err));
                   operation_status(err);
               }
               shutdown=1;
               break;
            }
            phase=0;
        }

        if(mode==1)
        {
            if(idle_time>=SLAVE_COMMAND_MODE_IDLE_TIME)
            {
                log_message(logger,LOG_INFO,"Performing slave shutdown because of timeout");
                pid_lock();
                _request_shutdown();
                pid_unlock();
            }
        }
        else if(mode==0)
        {
            if(idle_time>=MASTER_COMMAND_MODE_IDLE_TIME)
            {
                //check for slaves
                pid_lock();
                int msc = _master_get_slave_count();
                int osc = terminate_orphans?_master_get_orphans_count():0;
                if( msc<=0 && osc<=0 )
                {
                    log_message(logger,LOG_INFO,"Performing shutdown because of timeout");
                    _request_shutdown();
                }
                pid_unlock();
                idle_time=0;
            }
        }
    }

    log_message(logger,LOG_INFO,"Command loop is shutting down");
    command_mode=1;
    pid_lock();
    _request_shutdown();
    pid_unlock();

#define wait_for_term_routine(x_cnt, x_time_limit, x_count_func) \
    { int time_left=x_time_limit; \
      while(time_left>0 && x_cnt>0) \
      { pid_lock(); x_cnt=x_count_func(); pid_unlock(); \
        if(x_cnt>0) usleep(250*1000); time_left-=250; } }

#define conditional_term_routine(x_cnt, x_term_func, x_signal) \
    { if(x_cnt>0) \
      { pid_lock(); log_message(logger,LOG_INFO,"There are still %i processes left, sending %i signal",LI(x_cnt),LI(x_signal)); \
        x_term_func(x_signal); pid_unlock(); } }

    //in master mode, terminate slaves that may be left
    if(mode==0)
    {
        log_message(logger,LOG_INFO,"Awaiting and terminating slave executors");
        int s_cnt=0;
        pid_lock();
        s_cnt=_master_get_slave_count();
        pid_unlock();
        wait_for_term_routine(s_cnt,MASTER_SHUTDOWN_WAIT_TIME_INTERVAL,_master_get_slave_count);
        conditional_term_routine(s_cnt,_master_terminate_slaves,SIGTERM);
        wait_for_term_routine(s_cnt,MASTER_SHUTDOWN_WAIT_TIME_INTERVAL,_master_get_slave_count);
        conditional_term_routine(s_cnt,_master_terminate_slaves,SIGUSR1);
        wait_for_term_routine(s_cnt,MASTER_SHUTDOWN_WAIT_TIME_INTERVAL,_master_get_slave_count);
        conditional_term_routine(s_cnt,_master_terminate_slaves,SIGKILL);

        if(terminate_orphans)
        {
            int o_cnt=0;
            pid_lock();
            o_cnt=_master_get_orphans_count();
            pid_unlock();
            log_message(logger,LOG_INFO,"Awaiting and terminating orphan processes");
            conditional_term_routine(o_cnt,_master_terminate_orphans,SIGTERM);
            wait_for_term_routine(o_cnt,MASTER_SHUTDOWN_WAIT_TIME_INTERVAL,_master_get_orphans_count);
            conditional_term_routine(o_cnt,_master_terminate_orphans,SIGKILL);
        }
    }

    int ec=remove(filename_in);
    if(ec!=0)
        log_message(logger,LOG_WARNING,"Failed to remove pipe at %s, ec==%i",LS(filename_in),LI(ec));
    ec=remove(filename_out);
    if(ec!=0)
        log_message(logger,LOG_WARNING,"Failed to remove pipe at %s, ec==%i",LS(filename_out),LI(ec));

    int pos=0;
    while(params[pos]!=NULL)
    {
        free(params[pos]);
        ++pos;
    }
    free(params);

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

static unsigned long long current_timestamp(void)
{
    struct timeval te;
    gettimeofday(&te, NULL);
    return (unsigned long long)(te.tv_sec*1000LL + te.tv_usec/1000);
}

static uint8_t operation_status(uint8_t ec)
{
    uint8_t cmdbuf[CMDHDRSZ];
    CMDHDR cmd;
    cmd.cmd_type=ec;
    cmdhdr_write(cmdbuf,0,cmd);
    uint8_t ec2=message_send(fdo,tmp_buf,cmdbuf,0,CMDHDRSZ,key,REQ_TIMEOUT_MS);
    if(ec2!=0)
       log_message(logger,LOG_ERROR,"Failed to send response with operation result");
    return ec2;
}

static pid_t spawn_slave(char * new_channel)
{
    if(self==NULL)
    {
        log_message(logger,LOG_ERROR,"Self exec not set, cannot re-spawn self");
        return 0;
    }
    //<mode 0-master 1-slave> <logfile 0-disable 1-enable> <control dir> <channel-name> <security key>
    char skey[256];
    sprintf(skey,"%d",key);
    char slave[4];
    sprintf(slave,"%d",1);
    char log_en[4];
    sprintf(log_en,"%d",log_file_enabled);
    char * const self_params[7]=
    {
        self,
        slave,
        log_en,
        ctldir,
        new_channel,
        skey,
        NULL
    };
    pid_t pid = fork();
    if (pid == -1)
    {
        log_message(logger,LOG_ERROR,"Failed to perform fork");
        pid_unlock();
        return 0;
    }
    if(pid==0)
    {
        if(setsid()<0)
        {
            perror("setsid failed!");
            exit(1);
        }
        log_closefile(logger);
        if(close(fdi)!=0 || close(fdo)!=0)
        {
            perror("close of open file descriptors failed");
            exit(2);
        }
        execv(self,self_params);
        perror("execv failed");
        exit(3);
    }
    log_message(logger,LOG_INFO,"Started new slave executor with pid %i",LI(pid));
    return pid;
}

static uint8_t operation_0(char* channel_name, size_t len)
{
    if(mode==1)
    {
        log_message(logger,LOG_ERROR,"Slave executor for channel %s cannot spawn another slave executor",LI(channel));
        return 20;
    }

    pid_lock();
    if(shutdown)
    {
        log_message(logger,LOG_WARNING,"Master is shutting down, will not attempt to spawn anything");
        return 21;
    }

    pid_t pid;
    char chn[len==0?256:(len+1)];
    if(len==0)
    {
        sprintf(chn,"%04llx", current_timestamp());
        pid=spawn_slave(chn);
        len=256;
    }
    else
    {
        strncpy(chn,channel_name,len);
        chn[len]='\0';
        pid=spawn_slave(chn);
    }

    if(pid==0)
    {
        log_message(logger,LOG_ERROR,"Failed to spawn slave executor for channel %s",LI(chn));
        pid_unlock();
        return 12;
    }
    //try to open/close pipe
    int timeout=REQ_TIMEOUT_MS;
    char chn_in[len+4];
    sprintf(chn_in,"%s.in",chn);
    char chn_out[len+5];
    sprintf(chn_out,"%s.out",chn);
    while(timeout>0)
    {
        int t_fdi=open(chn_in,O_RDWR);
        int t_fdo=open(chn_out,O_RDWR);
        if(t_fdi>0 && t_fdo>0)
        {
            if((close(t_fdi)|close(t_fdo))!=0)
            {
               log_message(logger,LOG_ERROR,"Slave channel test failed! (close)");
               return 10;
            }
            break;
        }
        else
        {
            close(t_fdi);
            close(t_fdo);
        }
        usleep(WORKER_REACT_TIME_MS*1000);
        timeout-=WORKER_REACT_TIME_MS;
    }
    if(timeout<=0)
    {
       log_message(logger,LOG_ERROR,"Slave channel test failed! (timeout)");
       pid_unlock();
       return 11;
    }
    pid_list_add(_slave_list,pid);
    pid_unlock();

    //send response
    CMDHDR response;
    response.cmd_type=0;
    cmdhdr_write(data_buf,0,response);
    size_t data_len=strnlen(chn,len);
    strncpy((char*)(data_buf+CMDHDRSZ),chn,data_len);
    data_len+=CMDHDRSZ;
    uint8_t ec=message_send(fdo,tmp_buf,data_buf,0,(int32_t)data_len,key,REQ_TIMEOUT_MS);
    if(ec!=0 && ec!=255)
        log_message(logger,LOG_ERROR,"Failed to send response with newly created channel name %i",LI(ec));
    return 0;
}

static uint8_t operation_1(char* exec, size_t len)
{
    if(len>0 && exec!=NULL)
    {
        if(params[0]!=NULL)
            free(params[0]);
        params[0]=(char*)safe_alloc(len+1,1);
        params[0][len]='\0';
        strncpy(params[0],exec,len);
        log_message(logger,LOG_INFO,"File-name to exec was set to %s",LS(params[0]));
        if(operation_status(0)!=0)
            return 255;
        return 0;
    }
    else
        return 1;
}

static uint8_t operation_2(char* param, size_t len)
{
    if(len>0 && param!=NULL)
    {
        char** tmp=(char**)safe_alloc((size_t)(params_count+2),sizeof(char*));
        for(int i=0;i<params_count;++i)
            tmp[i]=params[i];
        params_count+=1;
        free(params);
        params=tmp;
        int cur=params_count-1;
        params[cur]=(char*)safe_alloc(len+1,1);
        params[cur][len]='\0';
        strncpy(params[cur],param,len);
        log_message(logger,LOG_INFO,"Added exec param %s, total params count %i",LS(params[cur]),LI(params_count));
        //add null-pointer to the end of the list
        params[params_count]=NULL;
        if(operation_status(0)!=0)
            return 255;
        return 0;
    }
    else
        return 1;
}

static uint8_t operation_3(char* name, size_t n_len, char* value, size_t v_len)
{
    if(n_len>0 && name!=NULL)
    {

        if(child_envset_count==0)
        {
            child_envset_count=1;
            child_envset_n=(char**)safe_alloc(1,sizeof(char*));
            child_envset_v=(char**)safe_alloc(1,sizeof(char*));
        }
        else
        {
            char** tmp=(char**)safe_alloc((size_t)(child_envset_count+1),sizeof(char*));
            for(int i=0;i<child_envset_count;++i)
                tmp[i]=child_envset_n[i];
            free(child_envset_n);
            child_envset_n=tmp;
            tmp=(char**)safe_alloc((size_t)(child_envset_count+1),sizeof(char*));
            for(int i=0;i<child_envset_count;++i)
                tmp[i]=child_envset_v[i];
            free(child_envset_v);
            child_envset_v=tmp;
            ++child_envset_count;
        }

        int cur=child_envset_count-1;
        child_envset_n[cur]=(char*)safe_alloc(n_len+1,1);
        child_envset_n[cur][n_len]='\0';
        strncpy(child_envset_n[cur],name,n_len);

        if(v_len<1||value==NULL)
            v_len=0;
        child_envset_v[cur]=(char*)safe_alloc(v_len+1,1);
        child_envset_v[cur][v_len]='\0';
        if(v_len>0)
            strncpy(child_envset_v[cur],value,v_len);

        log_message(logger,LOG_INFO,"Added env variable to set %s=%s",LS(child_envset_n[cur]),LI(child_envset_v[cur]));
        if(operation_status(0)!=0)
            return 255;
        return 0;
    }
    else
        return 1;
}

static uint8_t operation_4(char* name, size_t n_len)
{
    if(n_len>0 && name!=NULL)
    {

        if(child_envdel_count==0)
        {
            child_envdel_count=1;
            child_envdel_v=(char**)safe_alloc(1,sizeof(char*));
        }
        else
        {
            char** tmp=(char**)safe_alloc((size_t)(child_envdel_count+1),sizeof(char*));
            for(int i=0;i<child_envdel_count;++i)
                tmp[i]=child_envdel_v[i];
            free(child_envdel_v);
            child_envdel_v=tmp;
            ++child_envdel_count;
        }

        int cur=child_envdel_count-1;
        child_envdel_v[cur]=(char*)safe_alloc(n_len+1,1);
        child_envdel_v[cur][n_len]='\0';
        strncpy(child_envdel_v[cur],name,n_len);

        log_message(logger,LOG_INFO,"Added env variable to delete %s",LS(child_envdel_v[cur]));
        if(operation_status(0)!=0)
            return 255;
        return 0;
    }
    else
        return 1;
}

static uint8_t operation_5(uint8_t signal)
{
    if(signal<_NSIG)
    {
        child_signal=signal;
        child_signal_set=1;
        log_message(logger,LOG_INFO,"Signal to stop the process was set to %i",LI(signal));
        if(operation_status(0)!=0)
            return 255;
        return 0;
    }
    else
        return 1;
}

static uint8_t operation_6(char* dir, size_t len)
{
    if(len>0 && dir!=NULL)
    {
        if(workdir!=NULL)
            free(workdir);
        workdir=(char*)safe_alloc(len+1,1);
        workdir[len]='\0';
        strncpy(workdir,dir,len);
        log_message(logger,LOG_INFO,"Workdir was set to %s",LS(workdir));
        if(operation_status(0)!=0)
            return 255;
        return 0;
    }
    else
        return 1;
}

static uint8_t operation_250(void)
{
    if(mode==1)
    {
        log_message(logger,LOG_ERROR,"Operation is disabled for slave executor");
        return 20;
    }
    pid_lock();
    uint32_t count=(uint32_t)_master_get_orphans_count();
    pid_unlock();
    //send response
    CMDHDR response;
    response.cmd_type=0;
    cmdhdr_write(data_buf,0,response);
    u32_write(data_buf,CMDHDRSZ,count);
    uint8_t ec=message_send(fdo,tmp_buf,data_buf,0,(int32_t)(CMDHDRSZ+4),key,REQ_TIMEOUT_MS);
    if(ec!=0 && ec!=255)
        log_message(logger,LOG_ERROR,"Failed to send response with orphans count",LI(ec));
    return 0;
}

static uint8_t operation_253(bool grace_shutdown)
{
    if(mode==0)
        _master_terminate_slaves(grace_shutdown?SIGTERM:SIGUSR1);
    if(operation_status(0)!=0)
        return 255;
    return 0;
}

static uint8_t request_child_shutdown(bool grace_shutdown, bool skip_responce)
{
    if(grace_shutdown)
        log_message(logger,LOG_INFO,"Gracefully terminating child processes");
    else
        log_message(logger,LOG_INFO,"Sending SIGKILL signal to child processes");

    pid_lock();
    _slave_terminate_child(grace_shutdown?0:SIGKILL);
    pid_unlock();

    if(!skip_responce && operation_status(0)!=0)
        return 255;
    return 0;
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

static uint8_t operation_100_101_200_201(uint8_t comm_detached, uint8_t use_pty)
{
    //do not allow this operaion in master mode
    if(mode==0)
    {
        log_message(logger,LOG_WARNING,"Spawning for user processes is not allowed in master mode!");
        operation_status(107);
        return 0;
    }

    if(params[0]==NULL || params_count<1)
    {
        log_message(logger,LOG_ERROR,"Exec filename is not set, there is nothing to start");
        return 105;
    }

    int stdout_pipe[2];
    int stderr_pipe[2];
    int stdin_pipe[2];

    int fdm=-1;
    int stdout_bak=-1;
    int stderr_bak=-1;
    int stdin_bak=-1;

    if(use_pty)
    {
        if(!child_signal_set)
        {
            child_signal=SIGHUP;
            child_signal_set=1;
            log_message(logger,LOG_INFO,"Using default termination signal for pty-enabled session. signal=%i",LI(child_signal));
        }

        //baskup current stdout,stderr,stdin
        while( ((stdout_bak = dup(STDOUT_FILENO)) == -1) && (errno == EINTR)) {}
        while( ((stderr_bak = dup(STDERR_FILENO)) == -1) && (errno == EINTR)) {}
        while( ((stdin_bak = dup(STDIN_FILENO)) == -1) && (errno == EINTR)) {}

        int fds=-1;
        if(openpty(&fdm,&fds,NULL,NULL,NULL)<0)
        {
            log_message(logger,LOG_ERROR,"openpty failed, errno=%i",LI(errno));
            return 111;
        }
        if(login_tty(fds)<0)
        {
            log_message(logger,LOG_ERROR,"login_tty failed, errno=%i",LI(errno));
            return 112;
        }
    }
    else
    {
        if ( pipe(stdout_pipe)!=0 || pipe(stderr_pipe)!=0 || pipe(stdin_pipe)!=0 )
        {
            log_message(logger,LOG_ERROR,"Failed to create pipe for use as stderr or stdout for child process");
            return 110;
        }
        if(!child_signal_set)
        {
            child_signal=SIGTERM;
            child_signal_set=1;
            log_message(logger,LOG_INFO,"Using default termination signal for non-pty-enabled session. signal=%i",LI(child_signal));
        }
    }
    log_message(logger,LOG_INFO,"Starting new process %s",LS(params[0]));

    pid_lock();
    if(shutdown)
    {
        pid_unlock();
        return 255;
    }

    //pid_t pid = use_pty ? forkpty(&fdm,NULL,NULL,NULL) : fork();
    pid_t pid = fork();
    if (pid == -1)
    {
        log_message(logger,LOG_ERROR,"Failed to perform fork");
        pid_unlock();
        return 120;
    }

    if(pid==0)
    {
        /*if(use_pty)
        {
            struct termios term_settings;
            if(tcgetattr(fds, &term_settings)!=0)
                exit(3);
            cfmakeraw(&term_settings);
            if(tcsetattr(fds,TCSANOW,&term_settings)!=0)
                exit(4);
        }*/

        if(use_pty)
        {
            if(close(fdm)!=0)
            {
                perror("close of master fd of pty failed");
                exit(1);
            }
            if(close(stdout_bak)!=0 || close(stderr_bak)!=0 || close(stdin_bak)!=0)
            {
                perror("close of backup std file descriptors failed");
                exit(1);
            }
        }

        log_closefile(logger);
        if(close(fdi)!=0 || close(fdo)!=0)
        {
            perror("close of open file descriptors failed");
            exit(1);
        }

        if(!use_pty)
        {
            //set process as pid-group leader
            if(setpgid(0,0)<0)
            {
                perror("setpgid failed");
                exit(1);
            }
            while((dup2(stdout_pipe[1], STDOUT_FILENO) == -1) && (errno == EINTR)) {}
            close(stdout_pipe[1]);
            close(stdout_pipe[0]);
            while((dup2(stderr_pipe[1], STDERR_FILENO) == -1) && (errno == EINTR)) {}
            close(stderr_pipe[1]);
            close(stderr_pipe[0]);
            while((dup2(stdin_pipe[0], STDIN_FILENO) == -1) && (errno == EINTR)) {}
            close(stdin_pipe[0]);
            close(stdin_pipe[1]);
        }

        if(child_envdel_count>0)
            for(int i=0;i<child_envdel_count;++i)
                if(unsetenv(child_envdel_v[i])!=0)
                {
                    perror("unsetenv failed");
                    exit(2);
                }
        if(child_envset_count>0)
            for(int i=0;i<child_envset_count;++i)
                if(setenv(child_envset_n[i],child_envset_v[i],1)!=0)
                {
                    perror("setenv failed");
                    exit(3);
                }
        execv(params[0],params);
        perror("execv failed");
        exit(1);
    }

    //reconnect stdout
    if(use_pty)
    {
        while((dup2(stdout_bak, STDOUT_FILENO) == -1) && (errno == EINTR)) {}
        while((dup2(stderr_bak, STDERR_FILENO) == -1) && (errno == EINTR)) {}
        while((dup2(stdin_bak, STDIN_FILENO) == -1) && (errno == EINTR)) {}
        if(close(stdout_bak)!=0 || close(stderr_bak)!=0 || close(stdin_bak)!=0)
            log_message(logger,LOG_WARNING,"Failed to close backup std fds");
    }

    command_mode=0;
    child_is_alive=1;
    pid_unlock();

    if(!use_pty)
    {
        if(close(stdout_pipe[1])!=0)
            log_message(logger,LOG_WARNING,"Failed to close stdout_pipe[1]!"); //should not happen
        if(close(stderr_pipe[1])!=0)
            log_message(logger,LOG_WARNING,"Failed to close stderr_pipe[1]!"); //should not happen
        if(close(stdin_pipe[0])!=0)
            log_message(logger,LOG_WARNING,"Failed to close stdin_pipe[0]!"); //should not happen
    }

    //send response for child startup
    uint8_t comm_alive=comm_detached?0:1;
    if(operation_status(0)!=0)
        comm_alive=0;
    log_message(logger,LOG_INFO,"Entering child process control loop",LS(params[0]));

    int32_t in_len=0;
    uint8_t o_data_empty=0;
    uint8_t e_data_empty=0;
    uint8_t o_closed=0;
    uint8_t e_closed=0;

    const size_t max_data_req=(size_t)(MSGPLMAXLEN-CMDHDRSZ);

    int ofd=use_pty?fdm:stdout_pipe[0];
    int ifd=use_pty?fdm:stdin_pipe[1];

#define process_child_output(xfd, x_closed, x_data_empty) \
        { size_t avail=bytes_avail(xfd); ssize_t d_count=0; \
          if(avail>0) \
          { if(avail>max_data_req) avail=max_data_req; \
            d_count=read(xfd,(void*)(chld_buf+CMDHDRSZ),avail); \
            if(d_count==-1) \
            { int err=errno; \
              if(err!=EINTR) log_message(logger,LOG_ERROR,"Error while reading stdout/stderr from child process %s, errno=%i",LS(params[0]),LI(err)); \
              d_count=0; } \
            x_data_empty=0; } \
          else if(x_data_empty<4) ++x_data_empty; \
          else if(!child_is_alive) { struct pollfd fds; fds.fd=(xfd); fds.events=0; fds.revents=0;poll(&fds,1,0); \
              if( fds.revents & POLLHUP || fds.revents & POLLERR || fds.revents & POLLNVAL ) x_closed=1; } \
          if(comm_alive) \
          { CMDHDR cmd; cmd.cmd_type=150; cmdhdr_write(chld_buf,0,cmd); \
            uint8_t ec=message_send(fdo,tmp_buf,chld_buf,0,(int32_t)d_count+(int32_t)CMDHDRSZ,key,REQ_TIMEOUT_MS); \
            if(ec!=0) { log_message(logger,LOG_WARNING,"Commander goes offline while sending child stdout/stderr, disconnecting commander."); comm_alive=0; } } }

    while(child_is_alive || o_data_empty<4 || e_data_empty<4 || !o_closed || !e_closed)
    {
        in_len=0;

        //read input from commander
        if(comm_alive)
        {
            uint8_t ec=message_read(fdi,tmp_buf,data_buf,0,&in_len,key,REQ_TIMEOUT_MS);
            if(ec!=0)
            {
                log_message(logger,LOG_WARNING,"Commander was timed-out/failed, disposing all stdout and stderr from child process, error code=%i",LI(ec));
                comm_alive=0;
            }
            else
            {
                CMDHDR cmd;
                cmd=cmdhdr_read(data_buf,0);
                if(cmd.cmd_type!=150 && cmd.cmd_type!=253 && cmd.cmd_type!=252)
                {
                    log_message(logger,LOG_WARNING,"Commander gone offline, disposing all stdout and stderr from child process");
                    comm_alive=0;
                }
                else
                {
                    in_len-=(int32_t)CMDHDRSZ;
                    if(in_len<0)
                    {
                        log_message(logger,LOG_WARNING,"Incorrect input data was received, disconnecting commander.");
                        comm_alive=0;
                    }
                    //child termination via signal (cmd 253)
                    else if(cmd.cmd_type==253)
                    {
                        if(in_len!=1)
                        {
                            log_message(logger,LOG_WARNING,"Bad payload length for termination request");
                            comm_alive=0;
                        }
                        else
                            request_child_shutdown((bool)(*(data_buf+CMDHDRSZ)),true);
                        in_len=0;
                    }
                    else if(cmd.cmd_type==252)
                    {
                        if(in_len!=4)
                        {
                            log_message(logger,LOG_WARNING,"Bad payload length for terminal size update request");
                            comm_alive=0;
                        }
                        else
                        {
                            struct winsize term_size;
                            term_size.ws_col=u16_read(data_buf,CMDHDRSZ);
                            term_size.ws_row=u16_read(data_buf,CMDHDRSZ+2);
                            term_size.ws_xpixel=0;
                            term_size.ws_ypixel=0;
                            if(ioctl(ifd,TIOCSWINSZ,&term_size)!=0)
                                log_message(logger,LOG_WARNING,"Failed to set terminal size");
                            else
                                log_message(logger,LOG_INFO,"Terminal size update requested to %ix%i",LI(term_size.ws_col),LI(term_size.ws_row));
                        }
                        in_len=0;
                    }
                }
            }
        }
        else //recconect logic
        {
            size_t avail=bytes_avail(fdi);
            if(avail>0)
            {
                log_message(logger,LOG_INFO,"Commander trying to recconect");
                int32_t rl=0;
                if(message_read(fdi,tmp_buf,data_buf,0,&rl,key,REQ_TIMEOUT_MS)!=0)
                    log_message(logger,LOG_WARNING,"Recconect failed (read error or timeout)");
                else if(rl<(int32_t)CMDHDRSZ)
                    log_message(logger,LOG_INFO,"Recconect failed (not enough data to decrypt command)");
                else if(cmdhdr_read(data_buf,0).cmd_type==253)
                {
                    if(rl!=(CMDHDRSZ+1))
                        log_message(logger,LOG_WARNING,"Bad payload length for termination request");
                    else
                        request_child_shutdown((bool)(*(data_buf+CMDHDRSZ)),false);
                }
                else if(rl!=CMDHDRSZ)
                    log_message(logger,LOG_INFO,"Recconect failed (bad length)");
                else if(use_pty && cmdhdr_read(data_buf,0).cmd_type!=255)
                    log_message(logger,LOG_INFO,"Recconect failed (wrong opcode for pty enabled mode)");
                else if(!use_pty && cmdhdr_read(data_buf,0).cmd_type!=254)
                    log_message(logger,LOG_INFO,"Recconect failed (wrong opcode)");
                else
                {
                    log_message(logger,LOG_INFO,"Sending response");
                    CMDHDR cmd;
                    cmd.cmd_type=0;
                    cmdhdr_write(data_buf,0,cmd);
                    if(message_send(fdo,tmp_buf,data_buf,0,CMDHDRSZ,key,REQ_TIMEOUT_MS)!=0)
                        log_message(logger,LOG_WARNING,"Recconect response send failed");
                    else
                    {
                        log_message(logger,LOG_INFO,"Recconect complete, redirecting child process output to commander");
                        comm_alive=1;
                    }
                }
            }
        }

        process_child_output(ofd,o_closed,o_data_empty);

        if(use_pty)
        {
            e_data_empty=o_data_empty;
            e_closed=o_closed;
        }
        else
            process_child_output(stderr_pipe[0],e_closed,e_data_empty);

        //send input from commander to stdio of child
        if(in_len>0)
        {
            if(write(ifd,(void*)(data_buf+CMDHDRSZ),(size_t)in_len)<0)
            {
                int err=errno;
                if(err!=EINTR)
                    log_message(logger,LOG_ERROR,"Error while writing stdin to child process %s, errno=%i",LS(params[0]),LI(err));
            }
        }

        if( !comm_alive && o_data_empty>0 && e_data_empty>0 )
        {
            uint8_t min_dada_empty=o_data_empty;
            if(min_dada_empty>e_data_empty)
                min_dada_empty=e_data_empty;
            usleep( (useconds_t)(DATA_WAIT_TIME_MS*1000*min_dada_empty) );
        }
    }
    log_message(logger,LOG_INFO,"Process %s was finished, control loop complete",LS(params[0]));

    //send info about control loop completion and child exit code
    if(comm_alive)
    {
        CMDHDR cmd;
        cmd.cmd_type=151;
        cmdhdr_write(data_buf,0,cmd);
        *(data_buf+CMDHDRSZ)=child_ec;
        uint8_t ec=message_send(fdo,tmp_buf,data_buf,0,CMDHDRSZ+1,key,REQ_TIMEOUT_MS);
        if(ec!=0)
            log_message(logger,LOG_WARNING,"Failed to send child's process exit code ec=%i",LI(ec));
    }

    if(use_pty)
    {
        log_message(logger,LOG_INFO,"Closing master fd of pty");
        if(close(fdm)!=0)
            log_message(logger,LOG_WARNING,"Failed to close master pty. ec=%i",LI(errno)); //should not happen
    }
    else
    {
        if(close(stdout_pipe[0])!=0)
            log_message(logger,LOG_WARNING,"Failed to close stdout_pipe[0]!"); //should not happen
        if(close(stderr_pipe[0])!=0)
            log_message(logger,LOG_WARNING,"Failed to close stdout_pipe[0]!"); //should not happen
        if(close(stdin_pipe[1])!=0)
            log_message(logger,LOG_WARNING,"Failed to close stdin_pipe[1]!"); //should not happen
    }

    return 255;
}

static void pid_lock(void)
{
    pthread_mutex_lock(&pid_mutex);
}

static void pid_unlock(void)
{
    pthread_mutex_unlock(&pid_mutex);
}
