#include "helper_macro.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <X11/extensions/XShm.h>

#include <stdio.h>
#include <stdlib.h>

static Display* display=NULL;

void teardown(const char* error, int code);

void teardown(const char* error, int code)
{
    if(error!=NULL)
    {
        perror(error);
        fprintf(stderr,"teardown: %s\n",error);
    }
    if(display!=NULL)
        XCloseDisplay(display);
    exit(code);
}

int main(void)
{
    display=XOpenDisplay(NULL);
    if(display==NULL)
        teardown("XOpenDisplay failed",10);
    int screen=DefaultScreen(display);
    Visual* visual=DefaultVisual(display,screen);
    unsigned int depth=(unsigned)DefaultDepth(display,screen);
    int major,minor;
    Bool pixmaps;
    fputs("->XShmQueryVersion\n",stderr);
    if(XShmQueryVersion(display,&major,&minor,&pixmaps)==False)
        teardown("XShmQueryVersion failed",0);
    XShmSegmentInfo* si=(XShmSegmentInfo *)safe_alloc(1,sizeof(XShmSegmentInfo));
    fputs("->XShmCreateImage\n",stderr);
    XImage* image=XShmCreateImage(display,visual,depth, ZPixmap,NULL,si,64,64);
    if(image==NULL)
        teardown("XShmCreateImage failed",11);
    fputs("->shmget\n",stderr);
    si->shmid=shmget(IPC_PRIVATE,(size_t)(image->bytes_per_line*image->height),IPC_CREAT|0600);
    if(si->shmid<0)
        teardown("shmget failed",12);
    fputs("->shmat\n",stderr);
    si->shmaddr=(char*)shmat(si->shmid,NULL,0);
    if(si->shmaddr==NULL)
        teardown("shmat failed",13);
    si->readOnly=False;
    image->data=si->shmaddr;
    fputs("->XShmAttach\n",stderr);
    if(!XShmAttach(display,si))
        teardown("XShmAttach failed",14);
    //TODO: put image to some hidden window or something
    fputs("->XFlush\n",stderr);
    if(!XFlush(display))
        teardown("XFlush failed",15);
    fputs("->XSync\n",stderr);
    if(!XSync(display,False))
        teardown("XSync failed",16);
    fputs("->XShmDetach\n",stderr);
    if(!XShmDetach(display,si))
        teardown("XShmDetach failed",17);
    fputs("->XDestroyImage\n",stderr);
    if(XDestroyImage(image)==False)
        teardown("XDestroyImage failed",18);
    fputs("->shmdt\n",stderr);
    if(shmdt(si->shmaddr)==-1)
        teardown("shmdt failed",19);
    fputs("->shmctl\n",stderr);
    if(shmctl(si->shmid,IPC_RMID,NULL)==-1)
        teardown("shmctl failed",20);
    free(si);
    teardown(NULL,0);
}
