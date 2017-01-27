#include "pid_group_holder.h"

#include <stdio.h>
#include <signal.h>
#include <string.h>

static void pid_holder(void);

pid_t spawn_pid_holder(void)
{
    pid_t pid=fork();
    if(pid<0)
    {
        perror("spawn_pid_holder:fork failed");
        exit(1);
    }
    if(pid==0)
    {
        if(setpgid(0,0)!=0)
        {
            perror("setpgid failed");
            exit(2);
        }
        pid_holder();
        exit(3); //shold not happen
    }
    return pid;
}

static void pid_holder(void)
{
    struct sigaction act;
    memset(&act,1,sizeof(struct sigaction));

    act.sa_handler=SIG_IGN;
    act.sa_flags=0;

    if( sigaction(SIGTERM, &act, NULL) < 0 || sigaction(SIGINT, &act, NULL) < 0 || sigaction(SIGHUP, &act, NULL) < 0 || sigaction(SIGUSR1, &act, NULL) < 0 || sigaction(SIGCHLD,&act,NULL) <0 )
    {
        fprintf(stderr,"Failed to set one of termination signals handlers to SIG_IGN\n");
        fflush(stderr);
        return;
    }

    while(1)
        sleep(10);
}
