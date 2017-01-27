#include "helper_macro.h"
#include "logger.h"


#include <stdlib.h>
#include <stddef.h>

int main(void)
{
    LogDef log=log_init();
    log_setlevel(log,LOG_INFO);
    log_stdout(log,1u);
    log_logfile(log,"logfile.txt");
    int test_val=0;
    log_headline(log,"TEST UTILITY START");

    log_headline(log,"TEST UTILITY EXIT");
    log_deinit(log);
}
