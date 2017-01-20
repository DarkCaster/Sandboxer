#ifndef EXECUTOR_WORKER_INCLUDED
#define EXECUTOR_WORKER_INCLUDED

#include "helper_macro.h"
#include "logger.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef void * WorkerDef;
//set logger
void worker_set_logger(LogDef _logger);
//start new worker, will not block. return NULL on error.
WorkerDef worker_launch(const char* ctldir, const char* channel, uint32_t key);
//may block. will also recursively shutdown all subworkers
void worker_shutdown(const WorkerDef _worker);


void worker_init_fork_lock(void);
void worker_deinit_fork_lock(void);

#ifdef __cplusplus
}
#endif

#endif
