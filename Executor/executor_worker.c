#include "helper_macro.h"
#include "executor_worker.h"
#include "comm_helper.h"
#include "cmd_defs.h"
#include "logger.h"
#include "dictionary.h"

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <pthread.h>
#include <sys/time.h>

struct strWorker
{
    pthread_mutex_t access_lock;
    DictDef child_workers;
    uint32_t key;
    uint8_t shutdown;
    char* ctldir;
    char* fifo_in_path;
    char* fifo_out_path;
    char* exec;
    char** params;
    uint32_t params_count;
    pthread_t thread;
};

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
    result->exec=NULL;
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

    if(worker->exec!=NULL)
        free(worker->exec);

    if(worker->params_count>0)
    {
        for(uint32_t i=0;i<worker->params_count;++i)
            free(worker->params[i]);
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
    int ec=message_send(fdo,tmpbuf,(uint8_t*)chn,0,len,key,REQ_TIMEOUT_MS);
    if(ec!=0)
        log_message(logger,LOG_ERROR,"Failed to send response with newly created channel name %i",LI(ec));
    free(tmpbuf);
    return 0;
}

static uint8_t operation_1(int fdo, Worker* this_worker, uint32_t key, char* exec, size_t len)
{
    uint8_t* tmpbuf=(uint8_t*)safe_alloc(DATABUFSZ,1);
    uint8_t cmdbuf[CMDHDRSZ];
    if(len>0 && exec!=NULL)
    {
        worker_lock(this_worker);
        this_worker->exec=(char*)safe_alloc(len+1,1);
        this_worker->exec[len]='\0';
        strncpy(this_worker->exec,exec,len);
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
    int ec=message_send(fdo,tmpbuf,cmdbuf,0,CMDHDRSZ,key,REQ_TIMEOUT_MS);
    if(ec!=0)
        log_message(logger,LOG_ERROR,"Failed to send response with operation completion result");
    free(tmpbuf);
    return 0;
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
            default:
                log_message(logger,LOG_WARNING,"Unknown operation code %i",LI(cmdhdr.cmd_type));
                break;
            }
            if(err!=0)
            {
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
    char* chn_out=worker->fifo_in_path;
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


