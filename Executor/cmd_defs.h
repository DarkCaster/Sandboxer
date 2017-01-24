#include "helper_macro.h"

struct strCmdHdr{
    uint8_t cmd_type;
};

#define CMDHDR struct strCmdHdr
#define CMDHDRSZ (sizeof(CMDHDR))

always_inline static uint16_t u16_read(const uint8_t * buffer, int32_t offset)
{
    return (uint16_t)( *(buffer+offset) | *(buffer+offset+1) << 8 );
}

always_inline static void u16_write(uint8_t * buffer, int32_t offset, uint16_t value)
{
    *(buffer+offset)=(uint8_t)(value & 0xFF);
    *(buffer+offset+1)=(uint8_t)((value>>8) & 0xFF);
}

always_inline static uint32_t u32_read(const uint8_t * buffer, int32_t offset)
{
    return (uint32_t)( *(buffer+offset) | *(buffer+offset+1) << 8 | *(buffer+offset+2) << 16 | *(buffer+offset+3) << 24 );
}

always_inline static void u32_write(uint8_t * buffer, int32_t offset, uint32_t value)
{
    *(buffer+offset)  =(uint8_t)(value & 0xFF);
    *(buffer+offset+1)=(uint8_t)((value>>8) & 0xFF);
    *(buffer+offset+2)=(uint8_t)((value>>16) & 0xFF);
    *(buffer+offset+3)=(uint8_t)((value>>24) & 0xFF);
}

always_inline static CMDHDR cmdhdr_read(uint8_t * buffer, int32_t offset)
{
    return *((CMDHDR*)(buffer+offset));
}

always_inline static void cmdhdr_write(uint8_t * buffer, int32_t offset, CMDHDR hdr)
{
    *((CMDHDR*)(buffer+offset))=hdr;
}
