#include "pid_list.h"

#define PidList struct strPidList

struct strPidList {
    pid_t* list;
    int count;
};

PidListDef pid_list_init(void)
{
    PidList* const result=(PidList*)safe_alloc(1,sizeof(PidList));
    result->count=0;
    result->list=NULL;
    return (PidListDef)result;
}

void pid_list_deinit(PidListDef list_instance)
{
    PidList* const list=(PidList*)list_instance;
    if(list->count>0)
        free(list->list);
    free(list);
}

void pid_list_add(PidListDef list_instance, pid_t value)
{
    PidList* const list=(PidList*)list_instance;
    if(list->list==NULL)
    {
        list->list=(pid_t*)safe_alloc(1,sizeof(pid_t));
        list->count=1;
    }
    else
    {
        pid_t* tmp=(pid_t*)safe_alloc((size_t)(list->count+1),sizeof(pid_t));
        for(int i=0;i<list->count;++i)
            tmp[i]=list->list[i];
        free(list->list);
        list->list=tmp;
        ++(list->count);
    }
    list->list[list->count-1]=value;
}

uint8_t pid_list_remove(PidListDef list_instance, pid_t value)
{
    PidList* const list=(PidList*)list_instance;
    if(list->list==NULL)
        return 0;
    for(int i=0;i<list->count;++i)
        if(list->list[i]==value)
        {
            --(list->count);
            if(list->count<1)
            {
                free(list->list);
                list->count=0;
                list->list=NULL;
                return 1;
            }
            else
            {
                for(int j=i;j<list->count;++j)
                    list->list[j]=list->list[j+1];
                pid_t* tmp=(pid_t*)safe_alloc((size_t)list->count,sizeof(pid_t));
                for(int j=0;j<list->count;++j)
                    tmp[j]=list->list[j];
                free(list->list);
                list->list=tmp;
                return 1;
            }
        }
    return 0;
}

int pid_list_count(PidListDef list_instance)
{
    return ((PidList*)list_instance)->count;
}
