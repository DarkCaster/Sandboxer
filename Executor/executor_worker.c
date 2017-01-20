#include "helper_macro.h"
#include "executor_worker.h"
#include "comm_helper.h"
#include "message.h"
#include "cmd_defs.h"
#include "logger.h"
#include "dictionary.h"

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>
#include <sys/time.h>
#include <sys/stat.h>

struct strWorker
{
    pthread_mutex_t access_lock;
    DictDef child_workers;
    uint32_t key;
    uint8_t shutdown;
    char* ctldir;
    char* fifo_in_path;
    char* fifo_out_path;
    char** params;
    uint32_t params_count;
    pthread_t thread;
};

static pthread_mutex_t fork_lock;

void worker_init_fork_lock(void)
{
    pthread_mutex_init(&fork_lock,NULL);
}

void worker_deinit_fork_lock(void)
{
    pthread_mutex_unlock(&fork_lock);
    pthread_mutex_destroy(&fork_lock);
}

static void worker_lock_fork(void)
{
    pthread_mutex_lock(&fork_lock);
}

static void worker_unlock_fork(void)
{
    pthread_mutex_unlock(&fork_lock);
}

#define Worker struct strWorker

static LogDef logger=NULL;

static Worker* worker_init(void)
{
    Worker* result=(Worker*)safe_alloc(1,sizeof(Worker));
    pthread_mutex_init(&(result->access_lock),NULL);
    result->fifo_in_path=NULL;
    result->fifo_out_path=NULL;
    result->ctldir=NULL;
    result->child_workers=NULL;
    result->params=NULL;
    result->params_count=0;
    return result;
}

static void worker_deinit(Worker* worker)
{
    if(worker->fifo_in_path!=NULL)
    {
        int ec=remove(worker->fifo_in_path);
        if(ec!=0)
            log_message(logger,LOG_ERROR,"Failed to remove pipe at %s, ec==%i",LS(worker->fifo_in_path),LI(ec));
        free(worker->fifo_in_path);
    }

    if(worker->fifo_out_path!=NULL)
    {
        int ec=remove(worker->fifo_out_path);
        if(ec!=0)
            log_message(logger,LOG_ERROR,"Failed to remove pipe at %s, ec==%i",LS(worker->fifo_out_path),LI(ec));
        free(worker->fifo_out_path);
    }

    if(worker->ctldir!=NULL)
        free(worker->ctldir);

    if(worker->child_workers!=NULL)
        dict_deinit(worker->child_workers);

    if(worker->params!=NULL)
    {
        int pos=0;
        while(worker->params[pos]!=NULL)
        {
            free(worker->params[pos]);
            ++pos;
        }
        free(worker->params);
    }

    pthread_mutex_unlock(&(worker->access_lock));
    pthread_mutex_destroy(&(worker->access_lock));
    free((void*)worker);
}

void worker_set_logger(LogDef _logger)
{
    logger=_logger;
}

static void worker_lock(Worker* worker)
{
    pthread_mutex_lock(&(worker->access_lock));
}

static void worker_unlock(Worker* worker)
{
    pthread_mutex_unlock(&(worker->access_lock));
}

static unsigned long long current_timestamp(void)
{
    struct timeval te;
    gettimeofday(&te, NULL);
    return (unsigned long long)(te.tv_sec*1000LL + te.tv_usec/1000);
}

static uint8_t operation_0(int fdo, Worker* this_worker, const char* ctldir, uint32_t key)
{
    uint8_t* tmpbuf=(uint8_t*)safe_alloc(DATABUFSZ,1);
    //create new worker thread, with new comm pair
    char chn[256];
    int len=sprintf(chn,"%04llx", current_timestamp());
    chn[len]='\0';
    WorkerDef child=worker_launch(ctldir,chn,key);
    if(child==NULL)
    {
        log_message(logger,LOG_ERROR,"Failed to create new worker for channel %s",LI(chn));
        chn[0]='\0';
        len=0;
    }
    else
    {
        worker_lock(this_worker);
        dict_set(this_worker->child_workers,chn,(uint8_t*)child);
        worker_unlock(this_worker);
    }
    //send back new pipe basename
    uint8_t ec=message_send(fdo,tmpbuf,(uint8_t*)chn,0,len,key,REQ_TIMEOUT_MS);
    if(ec!=0 && ec!=255)
        log_message(logger,LOG_ERROR,"Failed to send response with newly created channel name %i",LI(ec));
    free(tmpbuf);
    return ec;
}

static uint8_t operation_1(int fdo, Worker* this_worker, uint32_t key, char* exec, size_t len)
{
    uint8_t* tmpbuf=(uint8_t*)safe_alloc(DATABUFSZ,1);
    uint8_t cmdbuf[CMDHDRSZ];
    if(len>0 && exec!=NULL)
    {
        worker_lock(this_worker);
        if(this_worker->params[0]!=NULL)
            free(this_worker->params[0]);
        this_worker->params[0]=(char*)safe_alloc(len+1,1);
        this_worker->params[0][len]='\0';
        strncpy(this_worker->params[0],exec,len);
        log_message(logger,LOG_INFO,"File-name to exec was set to %s",LS(this_worker->params[0]));
        worker_unlock(this_worker);
        CMDHDR cmd;
        cmd.cmd_type=1;
        cmdhdr_write(cmdbuf,0,cmd);
    }
    else
    {
        CMDHDR cmd;
        cmd.cmd_type=255;
        cmdhdr_write(cmdbuf,0,cmd);
    }
    //send back new pipe basename
    uint8_t ec=message_send(fdo,tmpbuf,cmdbuf,0,CMDHDRSZ,key,REQ_TIMEOUT_MS);
    if(ec!=0 && ec!=255)
        log_message(logger,LOG_ERROR,"Failed to send response with operation completion result");
    free(tmpbuf);
    return ec;
}



static uint8_t operation_2(int fdo, Worker* this_worker, uint32_t key, char* param, size_t len)
{
    uint8_t* tmpbuf=(uint8_t*)safe_alloc(DATABUFSZ,1);
    uint8_t cmdbuf[CMDHDRSZ];
    if(len>0 && param!=NULL)
    {
        worker_lock(this_worker);
        char** tmp=(char**)safe_alloc(this_worker->params_count+2,sizeof(char*));
        for(uint32_t i=0;i<this_worker->params_count;++i)
            tmp[i]=this_worker->params[i];
        this_worker->params_count+=1;
        free(this_worker->params);
        this_worker->params=tmp;
        uint32_t cur=this_worker->params_count-1;
        this_worker->params[cur]=(char*)safe_alloc(len+1,1);
        this_worker->params[cur][len]='\0';
        strncpy(this_worker->params[cur],param,len);
        log_message(logger,LOG_INFO,"Added exec param %s, total params count %i",LS(this_worker->params[cur]),LI(this_worker->params_count));
        //add null-pointer to the end of the list
        this_worker->params[this_worker->params_count]=NULL;
        worker_unlock(this_worker);
        CMDHDR cmd;
        cmd.cmd_type=2;
        cmdhdr_write(cmdbuf,0,cmd);
    }
    else
    {
        CMDHDR cmd;
        cmd.cmd_type=255;
        cmdhdr_write(cmdbuf,0,cmd);
    }
    //send back new pipe basename
    uint8_t ec=message_send(fdo,tmpbuf,cmdbuf,0,CMDHDRSZ,key,REQ_TIMEOUT_MS);
    if(ec!=0)
        log_message(logger,LOG_ERROR,"Failed to send response with operation completion result");
    free(tmpbuf);
    return 0;
}

static uint8_t operation_status(int fdo, uint32_t key, uint8_t* tmpbuf, uint8_t ec)
{
    uint8_t cmdbuf[CMDHDRSZ];
    CMDHDR cmd;
    cmd.cmd_type=ec;
    cmdhdr_write(cmdbuf,0,cmd);
    uint8_t ec2=message_send(fdo,tmpbuf,cmdbuf,0,CMDHDRSZ,key,REQ_TIMEOUT_MS);
    if(ec2!=0)
       log_message(logger,LOG_ERROR,"Failed to send response with operation result");
    return ec2;
}

//0-dead,1-alive
static uint8_t pid_is_alive(const char* cmd_path, const char* exec)
{
    int fd=open(cmd_path,O_RDONLY|O_NONBLOCK);
    if(fd<0)
        return 0;
    size_t elen=strlen(exec);
    char test[elen];
    ssize_t rlen=read(fd,test,elen);
    close(fd);
    if(rlen!=(ssize_t)elen)
        return 0;
    if(strncmp(exec,test,elen)!=0)
        return 0;
    return 1;
}

static uint8_t operation_100_101(int fdi, int fdo, Worker* this_worker, uint32_t key, uint8_t comm_detached)
{
    uint8_t* tmpbuf=(uint8_t*)safe_alloc(DATABUFSZ,1);

    worker_lock(this_worker);
    char** params=this_worker->params;
    uint32_t params_count=this_worker->params_count;
    worker_unlock(this_worker);

    if(params[0]==NULL || params_count<1)
    {
        log_message(logger,LOG_ERROR,"Exec filename is not set, there is nothing to start");
        operation_status(fdo,key,tmpbuf,105);
        free(tmpbuf);
        return 105;
    }

    //size_t exec_len=strlen(params[0]);
    int stdout_pipe[2];
    int stderr_pipe[2];

    if ( pipe2(stdout_pipe,O_NONBLOCK)!=0 || pipe2(stderr_pipe,O_NONBLOCK)!=0 )
    {
        log_message(logger,LOG_ERROR,"Failed to create pipe for use as stderr or stdout for child process");
        operation_status(fdo,key,tmpbuf,110);
        free(tmpbuf);
        return 110;
    }

    log_message(logger,LOG_INFO,"Starting new process %s",LS(params[0]));

    worker_lock_fork();
    pid_t pid = fork();
    worker_unlock_fork();

    if (pid == -1)
    {
        log_message(logger,LOG_ERROR,"Failed to perform fork");
        operation_status(fdo,key,tmpbuf,120);
        free(tmpbuf);
        return 120;
    }

    if(pid==0)
    {
        //TODO: also add stdin redirection.
        while((dup2(stdout_pipe[1], STDOUT_FILENO) == -1) && (errno == EINTR)) {}
        close(stdout_pipe[1]);
        close(stdout_pipe[0]);
        while((dup2(stderr_pipe[1], STDERR_FILENO) == -1) && (errno == EINTR)) {}
        close(stderr_pipe[1]);
        close(stderr_pipe[0]);
        execv(params[0],params);
        exit(1);
    }

    if(close(stdout_pipe[1])!=0)
        log_message(logger,LOG_WARNING,"Failed to close stdout_pipe[1]!"); //should not happen
    if(close(stderr_pipe[1])!=0)
        log_message(logger,LOG_WARNING,"Failed to close stdout_pipe[1]!"); //should not happen

    //send response for child startup
    uint8_t comm_alive=comm_detached?0:1;
    if(operation_status(fdo,key,tmpbuf,(uint8_t)(100+comm_detached))!=0)
        comm_alive=0;

    //TODO: read from stdout\stderr and push it downstream, while child is alive or commander part is listening
    //if commander part is disconnected, continue to dispose incoming data while child is alive
    log_message(logger,LOG_INFO,"Worker for process %s now entering control loop",LS(params[0]));
    char cmd_path[256];
    sprintf(cmd_path,"/proc/%d/cmdline",(uint32_t)pid);
    uint8_t pid_alive=1;
    uint8_t data_present=1;
    int32_t in_len=0;
    uint8_t* in_buf=(uint8_t*)safe_alloc(MSGPLMAXLEN+1,1);
    uint8_t* out_buf=(uint8_t*)safe_alloc(MSGPLMAXLEN+1,1);
    uint8_t* err_buf=(uint8_t*)safe_alloc(MSGPLMAXLEN+1,1);
    const size_t data_req=(size_t)(MSGPLMAXLEN-CMDHDRSZ);
    while(pid_alive || data_present)
    {
        data_present=1;
        in_len=0;

        //check pid is alive
        if(pid_alive)
            pid_alive &= pid_is_alive(cmd_path,params[0]);

        //read input from commander
        if(comm_alive)
        {
            if(message_read(fdi,tmpbuf,in_buf,0,&in_len,key,REQ_TIMEOUT_MS)!=0)
            {
                log_message(logger,LOG_WARNING,"Commander goes offline, disposing all stdout and stderr from child process");
                comm_alive=0;
            }
            else
            {
                CMDHDR cmd;
                cmd=cmdhdr_read(in_buf,0);
                //TODO: child termination
                if(cmd.cmd_type!=100)
                {
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
                }
            }
        }

        //read stdout  from child
        ssize_t out_count = read(stdout_pipe[0],(void*)(out_buf+CMDHDRSZ),data_req);
        if (out_count == -1)
        {
            if (errno != EINTR)
                log_message(logger,LOG_ERROR,"Error while reading stdout from child process %s",LS(params[0]));
            out_count=0;
            data_present=0;
        }

        //and stderr
        ssize_t err_count = read(stderr_pipe[0],(void*)(err_buf+CMDHDRSZ),data_req);
        if (err_count == -1)
        {
            if (errno != EINTR)
                log_message(logger,LOG_ERROR,"Error while reading stderr from child process %s",LS(params[0]));
            err_count=0;
            data_present=0;
        }

        //check if there some data left to read
        if((out_count<(ssize_t)data_req && err_count<(ssize_t)data_req)||(out_count==0&&err_count==0))
            data_present=0;

        //send output down to commander
        if(comm_alive)
        {
            CMDHDR cmd;
            cmd.cmd_type=100;

            cmdhdr_write(out_buf,0,cmd);
            int32_t olen=(int32_t)out_count+(int32_t)CMDHDRSZ;
            uint8_t ec=message_send(fdo,tmpbuf,out_buf,0,olen,key,REQ_TIMEOUT_MS);
            if(ec!=0)
                log_message(logger,LOG_WARNING,"Commander goes offline while sending child stdout, disconnecting commander.");

            cmdhdr_write(err_buf,0,cmd);
            int32_t elen=(int32_t)err_count+(int32_t)CMDHDRSZ;
            ec=message_send(fdo,tmpbuf,err_buf,0,elen,key,REQ_TIMEOUT_MS);
            if(ec!=0)
                log_message(logger,LOG_WARNING,"Commander goes offline while sending child stderr, disconnecting commander.");
        }
        //TODO: send input from commander to stdio of child
        //Wait a little, if data_present==0
        if(data_present==0)
            usleep(WORKER_REACT_TIME_MS*1000);
    }

    free(in_buf);
    free(out_buf);
    free(err_buf);

    if(close(stdout_pipe[0])!=0)
        log_message(logger,LOG_WARNING,"Failed to close stdout_pipe[0]!"); //should not happen
    if(close(stderr_pipe[0])!=0)
        log_message(logger,LOG_WARNING,"Failed to close stdout_pipe[0]!"); //should not happen

    free(tmpbuf);
    return 255;
}

static void * worker_thread (void* param)
{
    Worker* worker=(Worker*)param;
    worker_lock(worker);
    const char* fifo_in=worker->fifo_in_path;
    const char* fifo_out=worker->fifo_out_path;
    const char* ctldir=worker->ctldir;
    uint32_t seed=worker->key;
    uint8_t shutdown=worker->shutdown;
    log_message(logger,LOG_INFO,"Started new worker thread for %s|%s pipe",LS(fifo_in),LS(fifo_out));
    worker_unlock(worker);

    int fdi=open(fifo_in,O_RDWR);
    int fdo=open(fifo_out,O_RDWR);

    if(fdi<0||fdo<0)
    {
        log_message(logger,LOG_ERROR,"Failed to open %s|%s pipe",LS(fifo_in),LS(fifo_out));
        shutdown=1;
    }

    if(!shutdown)
        log_message(logger,LOG_INFO,"Worker is entering main loop, awaiting requests");

    uint8_t* tmpbuff=(uint8_t*)safe_alloc(DATABUFSZ,1);
    uint8_t* cmdbuf=(uint8_t*)safe_alloc(DATABUFSZ,1);

    uint8_t phase=0;
    int32_t pl_len=0;

    while(!shutdown)
    {
        if(phase==0)
        {
            int time_limit=WORKER_REACT_TIME_MS;
            uint8_t ec=message_read_header(fdi,tmpbuff,&time_limit);
            if(ec==0)
            {
                pl_len=0;
                phase=1;
            }
            else if(ec!=3 && ec!=255)
            {
                log_message(logger,LOG_ERROR,"Read error on %s pipe",LS(fifo_in));
                shutdown=1;
                break;
            }
        }

        if(phase==1)
        {
            int time_limit=WORKER_REACT_TIME_MS;
            uint8_t ec=message_read_and_transform_payload(fdi,tmpbuff,cmdbuf,0,&pl_len,seed,&time_limit);
            if(ec==0)
                phase=2;
            else if(ec!=3 && ec!=255)
            {
                log_message(logger,LOG_ERROR,"Read error on %s pipe",LS(fifo_in));
                shutdown=1;
                break;
            }
        }

        if(phase==2)
        {
            //we have read and properly decoded data, so extract "command" and decide what to do next
            CMDHDR cmdhdr=cmdhdr_read(cmdbuf,0);
            uint8_t err;
            switch(cmdhdr.cmd_type)
            {
            case 0:
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
                break;
            default:
                log_message(logger,LOG_WARNING,"Unknown operation code %i",LI(cmdhdr.cmd_type));
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

        worker_lock(worker);
        shutdown=worker->shutdown;
        worker_unlock(worker);
    };

    free(tmpbuff);
    free(cmdbuf);

    log_message(logger,LOG_INFO,"Worker thread for %s|%s pipe is shutting down",LS(fifo_in),LS(fifo_out));
    if(fdi>=0 && close(fdi)!=0)
        log_message(logger,LOG_ERROR,"Failed to close %s pipe",LS(fifo_in));
    if(fdo>=0 && close(fdo)!=0)
        log_message(logger,LOG_ERROR,"Failed to close %s pipe",LS(fifo_out));
    return NULL;
}

WorkerDef worker_launch(const char* ctldir, const char* channel, uint32_t key)
{
    const char * const ps="/";
    size_t ctl=strlen(ctldir);
    size_t pl=strlen(ps);
    size_t chl=strlen(channel);

    char filename_in[ctl+pl+chl+4];
    strcpy(filename_in,ctldir);
    strcpy(filename_in+ctl,ps);
    strcpy(filename_in+ctl+pl,channel);
    strcpy(filename_in+ctl+pl+chl,".in");
    filename_in[ctl+pl+chl+3]='\0';

    char filename_out[ctl+pl+chl+5];
    strcpy(filename_out,ctldir);
    strcpy(filename_out+ctl,ps);
    strcpy(filename_out+ctl+pl,channel);
    strcpy(filename_out+ctl+pl+chl,".out");
    filename_out[ctl+pl+chl+4]='\0';

    log_message(logger,LOG_INFO,"Starting new worker at control dir %s with channel %s",ctldir,channel);

    if(mkfifo(filename_in, 0600)!=0)
    {
        log_message(logger,LOG_ERROR,"Failed to create communication pipe at %s",filename_in);
        return NULL;
    }

    if(mkfifo(filename_out, 0600)!=0)
    {
        log_message(logger,LOG_ERROR,"Failed to create communication pipe at %s",filename_out);
        return NULL;
    }

    Worker* worker=worker_init();
    worker_lock(worker);
    worker->key=key;
    worker->shutdown=0;
    worker->fifo_in_path=(char*)safe_alloc(strlen(filename_in)+1,sizeof(char));
    worker->fifo_in_path[strlen(filename_in)]='\0';
    strcpy(worker->fifo_in_path,filename_in);
    worker->fifo_out_path=(char*)safe_alloc(strlen(filename_out)+1,sizeof(char));
    worker->fifo_out_path[strlen(filename_out)]='\0';
    strcpy(worker->fifo_out_path,filename_out);
    worker->ctldir=(char*)safe_alloc(ctl+1,sizeof(char));
    worker->ctldir[ctl]='\0';
    strcpy(worker->ctldir,ctldir);
    worker->child_workers=dict_init();
    worker->params=(char**)safe_alloc(2,sizeof(char*));
    worker->params_count=1;
    worker->params[0]=NULL;
    worker->params[1]=NULL;
    int ec=pthread_create(&(worker->thread),NULL,worker_thread,worker);
    worker_unlock(worker);
    if(ec!=0)
    {
        log_message(logger,LOG_ERROR,"Failed to create new thread, ec==%i",ec);
        worker_deinit(worker);
        return NULL;
    }
    return worker;
}

void worker_shutdown(const WorkerDef _worker)
{
    Worker* worker=(Worker*)_worker;
    if(worker==NULL)
        return;
    worker_lock(worker);
    char* chn_in=worker->fifo_in_path;
    char* chn_out=worker->fifo_out_path;
    worker_unlock(worker);
    log_message(logger,LOG_INFO,"Requesting shutdown for worker with comm pipes %s|%s",LS(chn_in),LS(chn_out));
    worker_lock(worker);
    worker->shutdown=1;
    worker_unlock(worker);
    int ec=pthread_join((worker->thread),NULL);
    if(ec!=0)
        log_message(logger,LOG_ERROR,"Error awaiting for worker's thread termination with pthread_join, ec==%i",ec);
    //shutdown child workers
    worker_lock(worker);
    char** keylist=dict_keylist(worker->child_workers);
    int pos=0;
    while(keylist[pos]!=NULL)
    {
        WorkerDef child=dict_get(worker->child_workers,keylist[pos]);
        worker_shutdown(child);
        ++pos;
    }
    dict_keylist_dispose(keylist);
    worker_unlock(worker);
    worker_deinit(worker);
    return;
}


