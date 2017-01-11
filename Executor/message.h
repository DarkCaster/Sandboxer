#ifndef LOGGER_INCLUDED
#define LOGGER_INCLUDED

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


#ifdef __cplusplus
}
#endif

#endif
