#include "pid_list.h"
#include <signal.h>
#include <stdio.h>
#include <dirent.h>
#include <string.h>
#include <ctype.h>

#define PidList struct strPidList

struct strPidList {
    pid_t* list;
    int count;
};

static int check_target_is_child(PidList* parents, pid_t target);

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

bool pid_list_check(PidListDef list_instance, pid_t value)
{
    PidList* const list=(PidList*)list_instance;
    if(list->count<=0)
        return false;
    for(int i=0;i<list->count;++i)
        if(list->list[i]==value)
            return true;
    return false;
}

void pid_list_add(PidListDef list_instance, pid_t value)
{
    if(pid_list_check(list_instance,value))
        return;
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

void pid_list_copy_2(PidListDef source, PidListDef target)
{
    PidList* const s_list=(PidList*)source;
    for(int i=0; i<s_list->count; ++i)
        pid_list_add(target,s_list->list[i]);
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
        return true;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpedantic"

#define num_max_len(num) ({ int sz=sizeof num; sz==1?3:(sz==2?5:(sz==4?10:(sz==8?20:256))); })
#define num_t_max_len(num) ({ int sz=sizeof(num); sz==1?3:(sz==2?5:(sz==4?10:(sz==8?20:256))); })

static uint8_t arg_is_numeric(const char* arg)
{
    size_t len=strlen(arg);
    for(size_t i=0;i<len;++i)
        if(!isdigit((int)arg[i]))
            return 0;
    return 1;
}

void pid_list_validate_slave_executors(PidListDef list_instance, pid_t parent)
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
static int check_target_is_child(PidList* parents, pid_t target)
{
    const int base_proc_stat_len=11; // /proc/<pid>/stat
    int stat_path_len=base_proc_stat_len+num_max_len(target);
    char stat_path[stat_path_len+1];
    stat_path[stat_path_len]='\0';

    sprintf(stat_path, "/proc/%d/stat", target);
    FILE* stat_file = fopen(stat_path,"r");
    if(stat_file==NULL)
        return -1;
    pid_t ppid=0;
    int v_read=fscanf(stat_file, "%*d %*s %*c %d", &ppid);
    fclose(stat_file);
    if(v_read!=1)
        return -2;
    for(int i=0; i<parents->count; ++i)
        if(ppid==parents->list[i])
            return 1;
    if(ppid==1)
        return 0;
    return check_target_is_child(parents,ppid);
}

bool populate_list_with_session_members(PidListDef list_instance, pid_t session)
{
    PidList* const list=(PidList*)list_instance;

    const int base_proc_stat_len=11; // /proc/<pid>/stat
    int stat_path_len=base_proc_stat_len+num_t_max_len(pid_t);
    char stat_path[stat_path_len+1];
    stat_path[stat_path_len]='\0';

    struct dirent* d_entry=NULL;
    FILE* stat_file=NULL;
    pid_t pid=0;
    pid_t sid=0;

    for(int i=0; i<2; ++i)
    {
        DIR* proc=opendir("/proc");
        if(proc==NULL)
            return false;
        while((d_entry = readdir(proc)) != NULL)
        {
            if(!arg_is_numeric(d_entry->d_name))
                continue;
            sprintf(stat_path, "/proc/%s/stat", d_entry->d_name);
            stat_file = fopen(stat_path,"r");
            if(stat_file==NULL)
                continue;
            int v_read=fscanf(stat_file, "%d %*s %*c %*d %*d %d", &pid, &sid);
            fclose(stat_file);
            if(v_read!=2)
                continue;
            if(i==0)
            {
                if( sid!=session )
                    continue;
                pid_list_add(list_instance,pid);
            }
            else
            {
                if(check_target_is_child(list,pid)==1)
                   pid_list_add(list_instance,pid);
            }
        }
        if(closedir(proc)!=0)
            return false;
    }
    return true;
}

bool populate_list_with_orphans(PidListDef list_instance, PidListDef ignored_parents)
{
    struct dirent* d_entry=NULL;
    DIR* proc=opendir("/proc");
    if(proc==NULL)
        return false;
    while((d_entry = readdir(proc)) != NULL)
    {
        if(!arg_is_numeric(d_entry->d_name))
            continue;
        pid_t pid=(pid_t)strtol(d_entry->d_name, NULL, 10);
        if(pid==1)
            continue;
        int check=check_target_is_child((PidList*)ignored_parents, pid);
        if(check>0 || check<0)
            continue;
        pid_list_add(list_instance, pid);
    }
    if(closedir(proc)!=0)
        return false;
    return true;
}

#pragma GCC diagnostic pop
