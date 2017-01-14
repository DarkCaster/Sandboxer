#include "helper_macro.h"
#include "executor_worker.h"
#include "logger.h"
#include "pthread.h"

#include <stdlib.h>
#include <stddef.h>

struct strWorker
{
    pthread_mutex_t access_lock;
    const char* key;
    pthread_t thread;


};

#define Worker struct strWorker

static Worker* worker_init()
{
    Worker* result=(Worker*)safe_alloc(1,sizeof(Worker));
    pthread_mutex_init(&(result->access_lock),NULL);
    result->thread=NULL;
}

static void worker_deinit(Worker* woker)
{
    pthread_mutex_unlock(&(woker->access_lock));
    pthread_mutex_destroy(&(woker->access_lock));
    free((void*)woker);
}

WorkerDef worker_launch(LogDef logger, const char* ctldir, const char* channel, uint32_t key)
{
    //char* filename

    Worker* worker=worker_init();


}




void worker_shutdown(const WorkerDef worker)
{

}

static void * worker (void* params)
{

}
