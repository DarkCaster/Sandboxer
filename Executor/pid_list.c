#include "pid_list.h"
#include <signal.h>
#include <stdio.h>

#define PidList struct strPidList

struct strPidList {
    pid_t* list;
    int count;
};

static bool check_target_is_child(PidList* parents, pid_t target);

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

bool pid_list_remove(PidListDef list_instance, pid_t value)
{
    PidList* const list=(PidList*)list_instance;
    if(list->list==NULL)
        return false;
    for(int i=0;i<list->count;++i)
        if(list->list[i]==value)
        {
            --(list->count);
            if(list->count<1)
            {
                free(list->list);
                list->count=0;
                list->list=NULL;
                return true;
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
                return true;
            }
        }
    return false;
}

int pid_list_count(PidListDef list_instance)
{
    return ((PidList*)list_instance)->count;
}

void pid_list_copy(PidListDef list_instance, pid_t* target)
{
    PidList* const list=(PidList*)list_instance;
    for(int i=0; i<list->count; ++i)
        target[i]=list->list[i];
}

bool pid_list_signal(PidListDef list_instance, int signal)
{
    PidList* const list=(PidList*)list_instance;
    if(list->count>0)
    {
        bool result=true;
        for(int i=0; i<list->count; ++i)
            if(kill(list->list[i],signal)!=0)
                result=false;
        return result;
    }
    else
        return false;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpedantic"

#define num_max_len(num) ({ int sz=sizeof num; sz==1?3:(sz==2?5:(sz==4?10:(sz==8?20:256))); })
#define num_t_max_len(num) ({ int sz=sizeof(num); sz==1?3:(sz==2?5:(sz==4?10:(sz==8?20:256))); })

void pid_list_validate(PidListDef list_instance, pid_t parent)
{
    PidList* const list=(PidList*)list_instance;

    //check current list
    if(list->count>0)
    {
        int count=list->count;
        pid_t tmp[count];
        pid_list_copy(list_instance,tmp);
        for(int i=0;i<count;++i)
            if(kill(tmp[i],0)!=0)
                pid_list_remove(list_instance,tmp[i]);
            else
            {
                const int base_proc_stat_len=11; // /proc/<pid>/stat
                int stat_path_len=base_proc_stat_len+num_max_len(tmp[i]);
                char stat_path[stat_path_len+1];
                stat_path[stat_path_len]='\0';
                sprintf(stat_path, "/proc/%d/stat", tmp[i]);
                FILE* stat_file = fopen(stat_path,"r");
                if(stat_file==NULL)
                { pid_list_remove(list_instance,tmp[i]); continue; }
                pid_t ppid=0;
                int v_read=fscanf(stat_file, "%*d %*s %*c %d", &ppid);
                fclose(stat_file);
                if( v_read!=1 || ppid!=parent || ppid==1 )
                { pid_list_remove(list_instance,tmp[i]); continue; }
            }
    }
}

//checks that target pid is belongs to parent pid tree
static bool check_target_is_child(PidList* parents, pid_t target)
{
    const int base_proc_stat_len=11; // /proc/<pid>/stat
    int stat_path_len=base_proc_stat_len+num_max_len(target);
    char stat_path[stat_path_len+1];
    stat_path[stat_path_len]='\0';

    sprintf(stat_path, "/proc/%d/stat", target);
    FILE* stat_file = fopen(stat_path,"r");
    if(stat_file==NULL)
        return false;
    pid_t ppid=0;
    int v_read=fscanf(stat_file, "%*d %*s %*c %d", &ppid);
    fclose(stat_file);
    if(v_read!=1)
        return false;
    for(int i=0; i<parents->count; ++i)
        if(ppid==parents->list[i])
            return true;
    if(ppid==1)
        return false;
    return check_target_is_child(parents,ppid);
}

#pragma GCC diagnostic pop
