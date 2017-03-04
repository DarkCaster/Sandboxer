#ifndef HELPER_MACRO_INCLUDED
#define HELPER_MACRO_INCLUDED

#include "config.h"

#ifdef HAVE_INTTYPES_H
    #include <inttypes.h>
#else
    #warning "inttypes.h is not available for your platform. Trying stdint.h"
    #ifdef HAVE_STDINT_H
        #include <stdint.h>
    #else
        #error "stdint.h is not available for your platform!"
    #endif
#endif

#ifdef HAVE_UNISTD_H
    #include <unistd.h>
#else
    #error "unistd is not available for your platform!"
#endif

#ifdef __GNUC__
    #ifndef always_inline
        #ifdef  __always_inline
            #define always_inline __always_inline
        #else
            #define always_inline __inline
        #endif
    #endif
#else
    #ifndef always_inline
        #define always_inline inline
    #endif
#endif

#include <stdbool.h>
#include <stdlib.h>

#define MAXALLOC 262144
#define MINALLOC_AWAIT 1000
#define MAXALLOC_RETRY 8

always_inline static void * safe_alloc(size_t el_count, size_t el_size)
{
    if((uint64_t)el_size+(uint64_t)el_count>MAXALLOC)
        exit(254);
    void * result=NULL;
    useconds_t delay=MINALLOC_AWAIT;
    for(int i=0;i<MAXALLOC_RETRY;++i)
    {
        result=calloc(el_count,el_size);
        if(result==NULL)
            usleep(delay);
        else
            break;
        delay=delay*2;
    }
    if(result==NULL)
        exit(253);
    return result;
}

#endif
