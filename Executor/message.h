#ifndef MESSAGE_INCLUDED
#define MESSAGE_INCLUDED

#include "helper_macro.h"
#include "hash.h"

#ifdef __cplusplus
extern "C" {
#endif

#define MSGHDRSZ 2
#define MSGLENTYPE uint16_t

#if DATABUFSZ>=(65535+MSGHDRSZ)
    #define MSGPLMAXLEN_RAW 65535
#else
    #define MSGPLMAXLEN_RAW (DATABUFSZ-MSGHDRSZ)
#endif

#define MSGPLMAXLEN (MSGPLMAXLEN_RAW-HASHSZ)

//helper methods, used when downloading message+it's payload
MSGLENTYPE msg_get_pl_len(const uint8_t* buffer, int32_t offset);
int32_t msg_get_pl_offset(int32_t offset);

//return len of data written to dest at dest_offset (-1==error while decoding), write decoded message contents to dest at dest_offset.
int32_t msg_decode(uint8_t* const dest, int32_t dest_offset, const uint8_t* src, int32_t src_offset, HSEEDTYPE h_seed);
//return len of data written to dest at dest_offset (-1==error while encoding), write encoded message contents to dest at dest_offset.
int32_t msg_encode(uint8_t* const dest, int32_t dest_offset, const uint8_t* src, int32_t src_offset, int32_t src_len, HSEEDTYPE h_seed);

#ifdef __cplusplus
}
#endif

#endif
