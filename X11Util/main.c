#include "helper_macro.h"
#include <sys/ipc.h>
#include <sys/shm.h>

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>

#define MAXARGLEN 4095

int mode_0(void);
int mode_1(void);

static void show_usage(void) {
    fputs("Usage: <mode number>\n",stderr);
    fputs("  Currently supported modes:\n",stderr);
    fputs("    0 - Perform simple test/hack with Sys.V SHM (may be needed for MIT-SHM X11 extension to work with sandbox's IPC isolation), and test x11 connection.\n",stderr);
    fputs("    1 - (TODO) Same as 0, but echo (to stdout) X11 env setup needed for clients to work. Then open X11 connection and wait forever for term signal. For use with some X11 forwarding and isolation software (like xpra).\n",stderr);
    exit(1);
}

static bool arg_is_numeric(const char* arg)
{
    size_t len=strnlen(arg,MAXARGLEN);
    for(size_t i=0;i<len;++i)
        if(!isdigit((int)arg[i]))
            return false;
    return true;
}

int main(int argc, char* argv[])
{
    if (argc != 2 || !arg_is_numeric(argv[1]))
        show_usage();
    /*
     * This is a simple hack, that tries to address this problem:
     * http://unix.stackexchange.com/questions/151884/x11-bad-access-at-first-try-but-working-on-successive-tries
     * Digging around with strace and debugger, i've found that maybe there is a possible problem somewhere around system-v shm usage at mit-shm x11 extension,
     * or cairo, or other lower-revel logic that used by various GUI toolkits to communitcate with X11.
     * What i've found so far: if shmget call returns value "0" (shm memory segment id) - X11 error occurs shortly after that (because of async model of xcb?).
     * "0" is NOT an invalid shm segment ID ("-1" is), but in normal case it is almost never happened that this call return "0".
     * But, ocassionaly, it happens on the first call to shmget when using IPC namespace isolation (sandboxing software like docker or bwrap do that)
     *
     * Maybe this is a bug somewhere at x11, or other lower level GUI code (return code from shmget compered with 0 insted of -1 ?).
     * Or maybe (likely) my investigation is wrong. But the folowing simple hack that i've develoved, seems to work.
     * It simply allocates shm segments several times to increase ID number returned by shmget calls.
     * So, when this call performed later by real gui application, first call to shmget will not return 0.
     */

    //Some more thoughts: if you set loop limit, say, to 500000, you can see how segment id counter overflows.
    //Right after overflow, ID is always set to "1". I've never seen, that it set to "0" after overflow!
    int last_seg = -1;
    for (int i = 0; i < 50 /*500000*/; ++i)
    {
        int seg = shmget(IPC_PRIVATE, 4096, IPC_CREAT | 0600);
        if(seg <= last_seg && seg != -1)
            fprintf(stderr, "shmget overflow. ID: %d\n", seg);
        if(seg == -1)
        {
            perror("shmget reports error");
            continue;
        }
        last_seg = seg;
        const void* ptr = shmat(seg, NULL, 0);
        if(ptr == (void*)-1)
        {
            perror("shmat reports error");
            continue;
        }
        if(shmctl(seg, IPC_RMID, NULL) == -1)
        {
            perror("shmctl reports error");
            continue;
        }
        if(shmdt(ptr) == -1)
            perror("shmdt reports error");
    }
    int mode=(int)strtol(argv[1], NULL, 10);
    if(mode>1)
        mode=1;
    if(mode==0)
       return mode_0();
    else
       return mode_1();
}

int mode_0(void)
{
    pid_t pid = fork();
    if(pid == -1)
    {
        perror("fork failed");
        return 5;
    }
    if(pid==0)
    {
        char cwd[4096];
        char* cwd_res=getcwd(cwd,4096);
        if(cwd_res==NULL)
        {
            perror("getcwd failed");
            exit(4);
        }
        char run[4096];
        sprintf(run,"%s/xshm_test",cwd_res);
        char * const args[2]=
        {
            run,
            NULL,
        };
        execv(run,args);
        perror("execv failed");
        exit(3);
    }
    siginfo_t siginfo;
    if(waitid(P_PID,(id_t)pid,&siginfo,WEXITED)!=0)
    {
        perror("waitid failed");
        exit(1);
    }
    return siginfo.si_status;
}

int mode_1(void)
{
    int ec=mode_0();
    if(ec!=0)
        return ec;
    //TODO: connect to x11, echo env to stdout, wait for sigterm.
    fputs("mode_1: not implemented!",stderr);
    return 1;
}
