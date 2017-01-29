#ifndef PID_LIST_INCLUDED
#define PID_LIST_INCLUDED

#include "helper_macro.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef void * PidListDef;

PidListDef pid_list_init(void);
void pid_list_deinit(PidListDef list_instance);
void pid_list_add(PidListDef list_instance, pid_t value);
bool pid_list_remove(PidListDef list_instance, pid_t value);
int pid_list_count(PidListDef list_instance);
void pid_list_copy(PidListDef list_instance,pid_t* target);
void pid_list_validate(PidListDef list_instance, pid_t parent);
bool pid_list_signal(PidListDef list_instance, int signal);

#ifdef __cplusplus
}
#endif

#endif
