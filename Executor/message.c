//message encoder\decoder.
//perform decode\encode data to\from buffer
//perform sign\verify of data buffer integrity
#include "message.h"
#include <string.h>

uint16_t msg_get_pl_len(const uint8_t* buffer, int32_t offset)
{
    return *((const uint16_t*)(buffer+offset));
}

static void msg_write_pl_len(uint8_t* const buffer, int32_t offset, uint16_t len)
{
    *((uint16_t* const)(buffer+offset))=len;
}

int32_t msg_get_pl_offset(int32_t offset)
{
    return offset+MSGHDRSZ;
}

int32_t msg_decode(uint8_t* const dest, int32_t dest_offset, const uint8_t* src, int32_t src_offset, HSEEDTYPE h_seed)
{
    uint16_t pl_len=msg_get_pl_len(src,src_offset);
    if(pl_len>MSGPLMAXLEN_RAW)
        return -1;
    if( !verify_hash(h_seed,src,src_offset+MSGHDRSZ,(int32_t)pl_len) )
        return -1;
    int32_t r_len=get_hpl_len((int32_t)pl_len);
    memcpy((void* const)(dest+dest_offset),(const void*)(src+src_offset+MSGHDRSZ),(size_t)r_len);
    return r_len;
}

//return len of data written to dest at dest_offset (-1==error while encoding), write encoded message contents to dest at dest_offset.
int32_t msg_encode(uint8_t* const dest, int32_t dest_offset, const uint8_t* src, int32_t src_offset, int32_t src_len, HSEEDTYPE h_seed)
{
    if(src_len<0 || src_len>MSGPLMAXLEN)
        return -1;
    memcpy((void* const)(dest+dest_offset+MSGHDRSZ),(const void*)(src+src_offset),(size_t)src_len);
    int32_t pl_len=append_hash(h_seed,dest,dest_offset+MSGHDRSZ,src_len);
    msg_write_pl_len(dest,dest_offset,(uint16_t)pl_len);
    return pl_len+MSGHDRSZ;
}
