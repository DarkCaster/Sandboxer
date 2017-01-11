#include "config.h"
#include "logger.h"
#include <string.h>

#define MAXARGLEN 256

int main(int argc, char* argv[])
{
    if(argc!=2)
        return -1;
    if(strnlen(argv[0], MAXARGLEN)>=MAXARGLEN)
        return -2;
    if(strnlen(argv[1], MAXARGLEN)>=MAXARGLEN)
        return -2;
    const char* input=argv[0];
    const char* logfile=argv[1];


}
