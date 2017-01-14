#include "helper_macro.h"
#include "executor_worker.h"
#include "logger.h"
#include "pthread.h"

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>

struct strWorker
{
    pthread_mutex_t access_lock;
    uint32_t key;
    uint8_t shutdown;
    char* fifo_path;
    pthread_t thread;
};

#define Worker struct strWorker

static LogDef logger=NULL;

static Worker* worker_init(void)
{
    Worker* result=(Worker*)safe_alloc(1,sizeof(Worker));
    pthread_mutex_init(&(result->access_lock),NULL);
    result->fifo_path=NULL;
    return result;
}

static void worker_deinit(Worker* woker)
{
    if(woker->fifo_path!=NULL)
    {
        int ec=remove(woker->fifo_path);
        if(ec!=0)
            log_message(logger,LOG_ERROR,"Failed to remove pipe at %s, ec==%i",LS(woker->fifo_path),LI(ec));
        free(woker->fifo_path);
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

static void * worker_thread (void* param)
{
    Worker* worker=(Worker*)param;
    worker_lock(worker);
    char* fifo=worker->fifo_path;
    uint32_t seed=worker->key;
    log_message(logger,LOG_INFO,"Started new worker thread for %s pipe",LS(fifo));
    worker_unlock(worker);
    uint8_t shutdown=0;
    do
    {
        worker_lock(worker);
        shutdown=worker->shutdown;
        worker_unlock(worker);
        usleep(500000);
        log_message(logger,LOG_INFO,"TICK! shutdown=%i",LI(shutdown));
    }while(!shutdown);
    log_message(logger,LOG_INFO,"Worker thread for %s pipe is shuting down",LS(fifo));
    return NULL;
}

WorkerDef worker_launch(const char* ctldir, const char* channel, uint32_t key)
{
    const char * const ps="/";
    size_t ctl=strlen(ctldir);
    size_t pl=strlen(ps);
    size_t chl=strlen(channel);
    char filename[ctl+pl+chl+1];
    strcpy(filename,ctldir);
    strcpy(filename+ctl,ps);
    strcpy(filename+ctl+pl,channel);
    filename[ctl+pl+chl]='\0';
    log_message(logger,LOG_INFO,"Starting new worker at control dir %s with channel %s",ctldir,channel);

    if(mkfifo(filename, 0600)!=0)
    {
        log_message(logger,LOG_ERROR,"Failed to create communication pipe at %s",filename);
        return NULL;
    }

    Worker* worker=worker_init();

    worker_lock(worker);
    worker->key=key;
    worker->shutdown=0;
    worker->fifo_path=(char*)safe_alloc(ctl+pl+chl+1,sizeof(char));
    worker->fifo_path[ctl+pl+chl]='\0';
    strcpy(worker->fifo_path,filename);
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


