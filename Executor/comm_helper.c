#include "comm_helper.h"
#include "message.h"
#include "errno.h"

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
        if(ec<0 && errno!=EINTR) //Error
            return -1;
        else if((ec<0 && errno==EINTR)||(ec==0))
            cur_time+=50;
        else
            break;
        if(shutdown)
            return timeout;
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
    //read msg_header
    uint8_t* rbuf=tmpbuf;
    ssize_t data_left=(ssize_t)sndlen;
    while(data_left>0)
    {
        ssize_t ec=write(fd,rbuf,(size_t)data_left);
        if(ec<0 && errno==EINTR)
            continue;
        else if(ec<0)
            return 4;
        data_left-=ec;
        if(data_left<0)
            return 6; //wtf ?!
        rbuf=(rbuf+ec);
    }
    return 0;
}

/*uint8_t message_send_2(int fd, uint8_t* const tmpbuf, const uint8_t* cmdbuf, int32_t offset, int32_t len, uint32_t seed, int* time_limit)
{
    int32_t sndlen=msg_encode(tmpbuf,0,cmdbuf,offset,len,seed);
    if(sndlen<0)
        return 1;
    int op_time=fd_wait(fd,*time_limit,POLLOUT);
    if(op_time<0)
        return 2; //Error
    if(shutdown)
        return 255;
    *time_limit-=op_time;
    if(*time_limit<=0)
    {
        *time_limit=0;
        return 3;
    }
    if(write(fd,tmpbuf,(size_t)sndlen)!=(ssize_t)sndlen)
        return 4;
    return 0;
}*/

uint8_t message_read_header(int fd, uint8_t* const tmpbuf, int* time_limit)
{
    //wait for msg_header
    int op_time=fd_wait(fd,*time_limit,POLLIN);
    if(op_time<0)
        return 2;
    if(shutdown)
        return 255;
    *time_limit-=op_time;
    if(*time_limit<=0)
    {
        *time_limit=0;
        return 3;
    }

    //read msg_header
    uint8_t* rbuf=tmpbuf;
    ssize_t data_left=(ssize_t)MSGHDRSZ;

    while(data_left>0)
    {
        ssize_t ec=read(fd,rbuf,(size_t)data_left);
        if(ec<0 && errno==EINTR)
            continue;
        else if(ec<0)
            return 4;
        data_left-=ec;
        if(data_left<0)
            return 6; //wtf ?!
        rbuf=(rbuf+ec);
    }
    return 0;
}

uint8_t message_read_and_transform_payload(int fd, uint8_t* const tmpbuf, uint8_t* cmdbuf, int32_t offset, int32_t* len, uint32_t seed, int* time_limit)
{
    MSGLENTYPE pl_len=msg_get_pl_len(tmpbuf,0);
    int32_t pl_offset=msg_get_pl_offset(0);
    //wait for msg payload
    int op_time=fd_wait(fd,*time_limit,POLLIN);
    if(op_time<0)
        return 2;
    if(shutdown)
        return 255;
    *time_limit-=op_time;
    if(*time_limit<0)
    {
        *time_limit=0;
        return 3;
    }

    //read msg payload
    uint8_t* rbuf=(tmpbuf+pl_offset);
    ssize_t data_left=pl_len;

    while(data_left>0)
    {
        ssize_t ec=read(fd,rbuf,(size_t)data_left);
        if(ec<0 && errno==EINTR)
            continue;
        else if(ec<0)
            return 4;
        data_left-=ec;
        if(data_left<0)
            return 6; //wtf ?!
        rbuf=(rbuf+ec);
    }

    //decode payload
    *len=msg_decode(cmdbuf,offset,tmpbuf,0,seed);
    if(*len<0)
    {
        *len=0;
        return 5;
    }
    return 0;
}

uint8_t message_read(int fd, uint8_t* const tmpbuf, uint8_t* cmdbuf, int32_t offset, int32_t* len, uint32_t seed, int timeout)
{
    uint8_t ec=message_read_header(fd, tmpbuf, &timeout);
    if(ec!=0)
        return ec;
    ec=message_read_and_transform_payload(fd,tmpbuf,cmdbuf,offset,len,seed,&timeout);
    if(ec!=0)
        return ec;
    return 0;
}

/*uint8_t message_read_2(int fd, uint8_t* const tmpbuf, uint8_t* cmdbuf, int32_t offset, int32_t* len, uint32_t seed, int* time_limit)
{
    uint8_t ec=message_read_header(fd,tmpbuf,time_limit);
    if(ec!=0)
        return ec;
    ec=message_read_and_transform_payload(fd,tmpbuf,cmdbuf,offset,len,seed,time_limit);
    if(ec!=0)
        return ec;
    return 0;
}*/


