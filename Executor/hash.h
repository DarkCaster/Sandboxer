#ifndef HASH_INCLUDED
#define HASH_INCLUDED

#include "config.h"

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

#define HASHSZ 4
#define HASHTYPE uint32_t
#define HSEEDTYPE uint32_t

//calculate hash value from data with selected length in buffer at selected offset
HASHTYPE get_hash(HSEEDTYPE seed, const uint8_t* data, int32_t offset, int32_t len);
//buffer = payload + hash at the end; full_len = paypoad_len + HASHSZ; return: 0=fail; !=0=ok
uint8_t verify_hash(HSEEDTYPE seed, const uint8_t* buffer, int32_t offset, int32_t full_len);
//calculate and append hash to the end of the data buffer; return new full_len for data in buffer; buffer must have at least HASHSZ bytes after offset+orig_len
int32_t append_hash(HSEEDTYPE seed, uint8_t* const buffer, int32_t offset, int32_t orig_len);
//return result payload len, return -1 on error
int32_t get_hpl_len(int32_t full_len);
#ifdef __cplusplus
}
#endif

#endif
