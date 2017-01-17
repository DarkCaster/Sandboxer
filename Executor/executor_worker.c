#include "helper_macro.h"
#include "executor_worker.h"
#include "comm_helper.h"
#include "cmd_defs.h"
#include "logger.h"
#include "pthread.h"

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>

struct strWorker
{
    pthread_mutex_t access_lock;
    uint32_t key;
    uint8_t shutdown;
    char* fifo_in_path;
    char* fifo_out_path;
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
    return result;
}

static void worker_deinit(Worker* woker)
{
    if(woker->fifo_in_path!=NULL)
    {
        int ec=remove(woker->fifo_in_path);
        if(ec!=0)
            log_message(logger,LOG_ERROR,"Failed to remove pipe at %s, ec==%i",LS(woker->fifo_in_path),LI(ec));
        free(woker->fifo_in_path);
    }

    if(woker->fifo_out_path!=NULL)
    {
        int ec=remove(woker->fifo_out_path);
        if(ec!=0)
            log_message(logger,LOG_ERROR,"Failed to remove pipe at %s, ec==%i",LS(woker->fifo_out_path),LI(ec));
        free(woker->fifo_out_path);
    }

    pthread_mutex_unlock(&(woker->access_lock));
    pthread_mutex_destroy(&(woker->access_lock));
    free((void*)woker);
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

static uint8_t operation_0(int fdo, uint32_t seed)
{
    return 0;
}

static void * worker_thread (void* param)
{
    Worker* worker=(Worker*)param;
    worker_lock(worker);
    const char* fifo_in=worker->fifo_in_path;
    const char* fifo_out=worker->fifo_out_path;
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
                err=operation_0(fdo,seed);
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
    worker->shutdown=1;
    worker_unlock(worker);
    int ec=pthread_join((worker->thread),NULL);
    if(ec!=0)
        log_message(logger,LOG_ERROR,"Error awaiting for worker's thread termination with pthread_join, ec==%i",ec);
    worker_deinit(worker);
    return;
}


