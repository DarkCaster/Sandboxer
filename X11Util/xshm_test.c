#include "helper_macro.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <X11/extensions/XShm.h>

#include <stdio.h>
#include <stdlib.h>

static Display* display=NULL;
static volatile bool x_err_received=false;

void teardown(const char* error, int code);
int x_err_handler(Display *display, XErrorEvent *event);

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

int x_err_handler(Display *disp, XErrorEvent *ev)
{
    char message[256];
    XGetErrorText(disp,ev->error_code,message, sizeof(message));
    fprintf(stderr,"Received X11 error: error_code=%hhu, message=\"%s\", request_code=%hhu, minor_code=%hhu\n",ev->error_code,message,ev->request_code,ev->minor_code);
    x_err_received=true;
    return 0;
}

int main(void)
{
    XSetErrorHandler(x_err_handler);
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
    fputs("test complete\n",stderr);
    if(x_err_received)
    {
        fputs("there was x11-error received during test, exiting with error code 50\n",stderr);
        teardown(NULL,50);
    }
    teardown(NULL,0);
}
