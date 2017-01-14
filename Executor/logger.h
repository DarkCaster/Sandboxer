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

typedef void * LogDef;

#define LOG_INFO     1u
#define LOG_WARNING  2u
#define LOG_STATUS   3u
#define LOG_ERROR    4u
#define LOG_ENDL     NULL

#ifdef LI
#error "LI macro already defined"
#endif
#define LI (const int64_t)

#ifdef LU
#error "LU macro already defined"
#endif
#define LU (const uint64_t)

#ifdef LF
#error "LF macro already defined"
#endif
#define LF (const long double)

#ifdef LC
#error "LC macro already defined"
#endif
#define LC (const int)

#ifdef LS
#error "LS macro already defined"
#endif
#define LS (const char*)

#ifdef LVP
#error "LVP macro already defined"
#endif
#define LVP (const void*)

LogDef log_init (void);

void log_deinit (LogDef log_instance);

void log_stdout(const LogDef log_instance, const uint8_t enable_output);
void log_logfile(const LogDef log_instance, const char * filename);
void log_setlevel(const LogDef log_instance, const uint8_t level);
void log_headline(const LogDef log_instance, const char * const text);
void log_message(const LogDef log_instance, uint8_t msg_type, const char * const format_message, ...);

#ifdef __cplusplus
}
#endif

#endif
