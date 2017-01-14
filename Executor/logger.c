//a very simple thread safe logger
#include "logger.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <ctype.h>
#include <string.h>
#include <pthread.h>

struct strLogInstance {
    uint8_t level;
    uint8_t stdout_active;
    FILE* logfile;
    char filename[LOG_FILENAMESZ+1];
    char nl[4];
    pthread_mutex_t global_lock;
};

#define LogInstance struct strLogInstance

const char LOG_TYPE[5][10]= {"UNKNOWN","INFO","WARNING","STATUS","ERROR"};

LogDef log_init(void)
{
    LogInstance* result=(LogInstance*)safe_alloc(1,sizeof(LogInstance));
    result->level=LOG_INFO;
    result->stdout_active=0u;
    result->filename[LOG_FILENAMESZ]='\0';
    result->logfile=NULL;
    result->nl[0]='\r';
    result->nl[1]='\n';
    result->nl[2]='\0';
    result->nl[3]='\0';
    pthread_mutex_init(&(result->global_lock),NULL);
    return (LogDef)result;
}

void log_deinit(LogDef log_instance)
{
    log_stdout(log_instance,0u);
    log_logfile(log_instance,NULL);
    pthread_mutex_unlock(&(((LogInstance*)log_instance)->global_lock));
    pthread_mutex_destroy(&(((LogInstance*)log_instance)->global_lock));
    free((LogInstance*)log_instance);
}

static void log_lock(const LogDef log_instance)
{
    pthread_mutex_lock( &(((LogInstance*)log_instance)->global_lock) );
}

static void log_unlock(const LogDef log_instance)
{
    pthread_mutex_unlock( &(((LogInstance*)log_instance)->global_lock) );
}

void log_stdout(const LogDef log_instance, const uint8_t enable_output)
{
    log_lock(log_instance);
    LogInstance* const log=(LogInstance*)log_instance;
    if (enable_output!=0u)
    {
        if (log->stdout_active==0u)
            log->stdout_active=1;
    }
    else
    {
        if (log->stdout_active==1u)
            log->stdout_active=0u;
    }
    log_unlock(log_instance);
}

static void log_closefile(LogInstance* log)
{
    if(log->logfile!=NULL)
    {
        fclose(log->logfile);
        log->logfile=NULL;
    }
}

static void _log_logfile(const LogDef log_instance, const char * filename)
{
    LogInstance* const log=(LogInstance*)log_instance;
    if(filename!=NULL)
    {
        if(strnlen(filename,LOG_FILENAMESZ+1)>LOG_FILENAMESZ)
            return;
        strncpy(log->filename,filename,LOG_FILENAMESZ);
        log_closefile(log);
        log->logfile=fopen(log->filename,"a");
    }
    else
        log_closefile(log);
}

void log_logfile(const LogDef log_instance, const char * filename)
{
    log_lock(log_instance);
    _log_logfile(log_instance,filename);
    log_unlock(log_instance);
}

void log_message(const LogDef log_instance, uint8_t msg_type, const char * const format_message, ...)
{
    log_lock(log_instance);
    const char * format=format_message;

    LogInstance* const log=(LogInstance*)log_instance;
    if (msg_type>LOG_ERROR) msg_type=0u;

    if ((msg_type<log->level)&&(msg_type!=0u))
    {
        log_unlock(log_instance);
        return;
    }

    char buffer[LOG_OUTBUFSZ+1];
    buffer[LOG_OUTBUFSZ]='\0';

    //Print header
    if(log->stdout_active)
        printf("[%s] ",LOG_TYPE[msg_type]);

    if (log->logfile!=NULL)
    {
        snprintf(buffer,LOG_OUTBUFSZ,"[%s] ",LOG_TYPE[msg_type]);
        if(fwrite((void*)buffer,strnlen(buffer,LOG_OUTBUFSZ),1,log->logfile)!=1)
            _log_logfile(log_instance,NULL);
    }

    if (format==LOG_ENDL)
    {
        log_unlock(log_instance);
        return;
    }

    if (*(format)!='\0')
    {
        va_list vl;
        va_start(vl,format_message);

        size_t bpos=0;
        do
        {
            if (*(format)!='%')
            {
                *(buffer+bpos)=*(format);
                bpos++;
            }
            else
            {
                format++; //Пропустим %
                switch(*(format))
                {
                case 'i':
                    snprintf(buffer+bpos,LOG_OUTBUFSZ-bpos,"%"PRIi64"",(int64_t)va_arg(vl,int64_t));
                    break;
                case 'u':
                    snprintf(buffer+bpos,LOG_OUTBUFSZ-bpos,"%"PRIu64"",(uint64_t)va_arg(vl,uint64_t));
                    break;
                case 'f':
                    snprintf(buffer+bpos,LOG_OUTBUFSZ-bpos,"%.4Lf",va_arg(vl,long double));
                    break;
                case 'c':
                    snprintf(buffer+bpos,LOG_OUTBUFSZ-bpos,"%c",va_arg(vl,int));
                    break;
                case 's':
                    snprintf(buffer+bpos,LOG_OUTBUFSZ-bpos,"%s",va_arg(vl,char*));
                    break;
                case 'p':
                    snprintf(buffer+bpos,LOG_OUTBUFSZ-bpos,"%p",va_arg(vl,void*));
                    break;
                case '%':
                    snprintf(buffer+bpos,LOG_OUTBUFSZ-bpos,"_");
                    break;
                case '\0':
                    format--;
                    break;
                default:
                    snprintf(buffer+bpos,LOG_OUTBUFSZ-bpos,"%c",*(format));
                }
                if (log->stdout_active)
                    printf(buffer);
                if (log->logfile!=NULL)
                {
                    if(fwrite((void*)buffer,strnlen(buffer,LOG_OUTBUFSZ),1,log->logfile)!=1)
                        _log_logfile(log_instance,NULL);
                }

                bpos=0;
            }

            format++;
        }while(*(format)!='\0');

        if(bpos)
        {
            *(buffer+bpos)='\0';
            if (log->stdout_active)
                printf(buffer);
            if (log->logfile!=NULL)
            {
                if(fwrite((void*)buffer,strnlen(buffer,LOG_OUTBUFSZ),1,log->logfile)!=1)
                    _log_logfile(log_instance,NULL);
            }
        }
        va_end(vl);
   }

   if (log->stdout_active)
   {
       printf("\n");
       fflush(stdout);
   }
   if (log->logfile!=NULL)
   {
       if(fwrite((void*)log->nl,strnlen(log->nl,4),1,log->logfile)!=1)
           _log_logfile(log_instance,NULL);
       fflush(log->logfile);
   }
   log_unlock(log_instance);
}

void log_headline (const LogDef log_instance, const char * const text)
{
    log_lock(log_instance);
    LogInstance* const log=(LogInstance*)log_instance;
    //Print header
    if(log->stdout_active)
    {
        puts(text);
        fflush(stdout);
    }
    if(log->logfile!=NULL)
    {
        if(fwrite((const void*)text,strnlen(text,LOG_OUTBUFSZ),1,log->logfile)!=1)
            _log_logfile(log_instance,NULL);
        if(fwrite((void*)log->nl,strnlen(log->nl,4),1,log->logfile)!=1)
            _log_logfile(log_instance,NULL);
        fflush(log->logfile);
    }
    log_unlock(log_instance);
}

void log_setlevel(const LogDef log_instance,const uint8_t level)
{
    log_lock(log_instance);
    if((level<LOG_INFO)||(level>LOG_ERROR))
        ((LogInstance*)log_instance)->level=LOG_INFO;
    else
        ((LogInstance*)log_instance)->level=level;
    log_unlock(log_instance);
}
