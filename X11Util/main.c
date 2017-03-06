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
int mode_2(void);

static void show_usage(void) {
    fputs("Usage: <mode number>\n",stderr);
    fputs("  Currently supported modes:\n",stderr);
    fputs("    0 - Perform simple test on X11 and MIT-SHM extension. (TODO: test other x11 stuff needed for today GUI-frameworks to work properly)\n",stderr);
    fputs("    1 - For use with IPC namespaces isolation: perform simple hack to increase first sys.v shm segment id, do not test MIT-SHM. Helps with some x11 apps running in ipc-isolated env. (see comments in source code of this utility for more info)\n",stderr);
    fputs("    2 - Perform all stuff from 0 and 1 modes, and echo (to stdout) X11 env setup needed for clients to work. Then open X11 connection and wait forever for term signal. For use with some X11 forwarding and isolation software (like xpra).\n",stderr);
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
    int mode=(int)strtol(argv[1], NULL, 10);
    if(mode>2)
        mode=2;
    if(mode==0)
       return mode_0();
    else if(mode==1)
       return mode_1();
    else
       return mode_2();
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
    /*
     * This is a simple hack, that tries to address this problem:
     * http://unix.stackexchange.com/questions/151884/x11-bad-access-at-first-try-but-working-on-successive-tries
     *
     * Looks like, this problem caused by mit-shm extension, that cannot work inside IPC-namespace because of shared memory mechanism isolation.
     * This behavior can be illustrated by xshm_test utility (see xshm_test.c for more details).
     * When utility executed inside IPC-namespace, XShmAttach call (and other similiar calls) will fail, and exactly the same X11 error (BadAccess) will be thrown.
     * (but, mit-shm extension still report it's availability, and calls that perform only local management of shared data - works)
     *
     * Also, i've found that even if running inside IPC isolated env, major GUI toolkits is able to run (sometimes, with graphical glitches - firefox for example).
     * But, sometimes, it throws the same BadAccess X11 error at first run.
     * Digging around with strace and debugger, i've found that maybe there is a possible problem somewhere in lower-revel logic
     * that used by various GUI toolkits to communitcate with X11. And it appears only in such isolated env.
     * I've found that if shmget call (used together with mit-shm extension functions) returns value "0" (shm memory segment id), then X11 error occurs shortly after that.
     * "0" is NOT an invalid shm segment ID ("-1" is), but in normal case it is almost never happened that this call return "0".
     * But, ocassionaly, it happens on the first call to shmget when using IPC namespace isolation (sandboxing software like docker or bwrap do that)
     *
     * Maybe this is a bug somewhere at x11, or other lower level GUI code (return code from shmget compered with 0 insted of -1 ?).
     * Or maybe (likely) my investigation is wrong.
     * The root cause of this problem - is an unavailability of shared memory interaction between isolated sandbox and host.
     * But the folowing simple hack that i've develoved, also seems to work.
     * It simply allocates shm segments several times to increase ID number returned by shmget calls.
     * So, when similiar call performed later by real gui application, first call to shmget will not return 0, and it is not fails at start.
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
    return 0;
}

int mode_2(void)
{
    int ec=mode_0();
    if(ec!=0)
        return ec;
    //TODO: connect to x11, echo env to stdout, wait for sigterm.
    fputs("mode_2: not implemented!",stderr);
    return 1;
}
