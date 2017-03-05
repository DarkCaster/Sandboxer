#include "helper_macro.h"
#include <sys/ipc.h>
#include <sys/shm.h>
#include <stdio.h>

static void show_usage(void)
{
    fprintf(stderr,"Usage: <mode number>\n");
    fprintf(stderr,"  Currently supported modes:\n");
    fprintf(stderr,"    0 - Perform simple test/hack with Sys.V SHM (may be needed for MIT-SHM X11 extension to work with sandbox's IPC isolation), and test x11 connection.\n");
    fprintf(stderr,"    1 - (TODO) Same as 0, but echo (to stdout) X11 env setup needed for clients to work. Then open X11 connection and wait forever for term signal. For use with some X11 forwarding and isolation software (like xpra).\n");
    exit(1);
}

int main(int argc, char* argv[])
{
    if(argc!=2)
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
     * Maybe this is a bug somewhere at x11, or other lower level GUI code (return code from shmget compered with 0 insted of -1).
     * Or maybe (likely) my investigation is wrong. But the folowing simple hack that i've develoved, seems to work.
     * It simply allocates shm segments several times to increase ID number returned by shmget calls.
     * So, when this call performed later by real gui application, first call to shmget will not return 0.
     */
    int seg=shmget(IPC_PRIVATE, 4096, IPC_CREAT|0600);
    const void* ptr=shmat(seg, NULL, 0);
    shmctl(seg, IPC_RMID, NULL);
    shmdt(ptr);
    return 0;
}
