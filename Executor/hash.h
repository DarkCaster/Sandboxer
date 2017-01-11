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

uint32_t get_hash( uint32_t seed, const uint8_t* data, int32_t offset, int32_t len );

#ifdef __cplusplus
}
#endif

#endif
