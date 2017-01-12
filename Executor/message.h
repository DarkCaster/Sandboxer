#ifndef MESSAGE_INCLUDED
#define MESSAGE_INCLUDED

#include "config.h"
#include "hash.h"

#ifdef HAVE_INTTYPES_H
    #include <inttypes.h>
#else
    #warning "inttypes.h is not available for your platform. Trying stdint.h"
    #ifdef HAVE_STDINT_H
        #include <stdint.h>
    #else
        #error "stdint.h is not available for your platform. You must manually define used types"
    #endif
#endif

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
