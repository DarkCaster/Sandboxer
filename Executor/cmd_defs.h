#include "helper_macro.h"

struct strCmdHdr{
    uint8_t cmd_type;
};

#define CMDHDR struct strCmdHdr
#define CMDHDRSZ (sizeof(CMDHDR))

always_inline static CMDHDR cmdhdr_read(uint8_t * buffer, uint32_t offset)
{
    return *((CMDHDR*)(buffer+offset));
}

always_inline static void cmdhdr_write(uint8_t * buffer, uint32_t offset, CMDHDR hdr)
{
    *((CMDHDR*)(buffer+offset))=hdr;
}
