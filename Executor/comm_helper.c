#include "comm_helper.h"
#include "message.h"

static volatile uint8_t shutdown;

void comm_shutdown(uint8_t _shutdown)
{
    shutdown=_shutdown;
}

int fd_wait(int fd, int timeout, short int events)
{
    struct pollfd fds;
    int cur_time=0;
    while(cur_time<timeout)
    {
        fds.fd=fd;
        fds.events=events;
        fds.revents=0;
        int ec=poll(&fds,1,50);
        if(ec<0) //Error
            return -1;
        else if(ec == 0) //TIMEOUT
            cur_time+=50;
        else
            break;
        if(shutdown)
            break;
    }
    return cur_time;
}

uint8_t message_send(int fd, uint8_t* const tmpbuf, const uint8_t* cmdbuf, int32_t offset, int32_t len, uint32_t seed, int timeout)
{
    int32_t sndlen=msg_encode(tmpbuf,0,cmdbuf,offset,len,seed);
    if(sndlen<0)
        return 1;
    int op_time=fd_wait(fd,timeout,POLLOUT);
    if(op_time<0)
        return 2; //Error
    if(shutdown)
        return 255;
    if(op_time>=timeout)
        return 3;
    if(write(fd,tmpbuf,(size_t)sndlen)!=(ssize_t)sndlen)
        return 4;
    return 0;
}

uint8_t message_read(int fd, uint8_t* const tmpbuf, uint8_t* cmdbuf, int32_t offset, int32_t* len, uint32_t seed, int timeout)
{
    int cur_time=0;
    //wait for msg_header
    int op_time=fd_wait(fd,timeout,POLLIN);
    if(op_time<0)
        return 2;
    if(shutdown)
        return 255;
    cur_time+=op_time;
    if(cur_time>=timeout)
        return 3;
    //read msg_header
    if(read(fd,tmpbuf,MSGHDRSZ)!=(ssize_t)MSGHDRSZ)
        return 4;
    MSGLENTYPE pl_len=msg_get_pl_len(tmpbuf,0);
    int32_t pl_offset=msg_get_pl_offset(0);
    //read msg payload
    //wait for msg payload
    op_time=fd_wait(fd,timeout-cur_time,POLLIN);
    if(op_time<0)
        return 2;
    if(shutdown)
        return 255;
    cur_time+=op_time;
    if(cur_time>=timeout)
        return 3;
    //read msg payload
    if(read(fd,(tmpbuf+pl_offset),pl_len)!=(ssize_t)pl_len)
        return 4;
    //decode payload
    *len=msg_decode(cmdbuf,offset,tmpbuf,0,seed);
    if(*len<0)
    {
        *len=0;
        return 5;
    }
    return 0;
}
