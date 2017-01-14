#ifndef HASH_INCLUDED
#define HASH_INCLUDED

#include "helper_macro.h"

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
