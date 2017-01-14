#ifndef EXECUTOR_WORKER_INCLUDED
#define EXECUTOR_WORKER_INCLUDED

#include "config.h"
#include "logger.h"

#ifdef HAVE_INTTYPES_H
    #include <inttypes.h>
#else
    #warning "inttypes.h is not available for your platform. Trying stdint.h"
    #ifdef HAVE_STDINT_H
        #include <stdint.h>
    #else
        #error "stdint.h is not available for your platform. You must manually define used types"
    #endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void * WorkerDef;

//init new worker, will not block. return NULL on error.
WorkerDef launch_worker(LogDef logger, const char* ctldir, const char* channel, uint32_t key);
//may block. will also recursively shutdown all subworkers
void shutdown_worker(const WorkerDef worker);

#ifdef __cplusplus
}
#endif

#endif
