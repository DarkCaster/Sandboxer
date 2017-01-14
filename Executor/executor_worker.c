#include "config.h"
#include "executor_worker.h"
#include "logger.h"
#include "pthread.h"

struct strWorker
{
    const char* key;
    pthread_t thread;

};

#define Worker struct strWorker

WorkerDef launch_worker(LogDef logger, const char* ctldir, const char* channel, uint32_t key)
{

}


void shutdown_worker(const WorkerDef worker)
{

}
