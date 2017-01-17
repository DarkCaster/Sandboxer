#include "helper_macro.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <poll.h>

void comm_shutdown(uint8_t _shutdown);
int fd_wait(int fd, int timeout, short int events);
uint8_t message_send(int fd, uint8_t* const tmpbuf, const uint8_t* cmdbuf, int32_t offset, int32_t len, uint32_t seed, int timeout);
uint8_t message_read(int fd, uint8_t* const tmpbuf, uint8_t* cmdbuf, int32_t offset, int32_t* len, uint32_t seed, int timeout);

//separate method for header read
uint8_t message_read_header(int fd, uint8_t* const tmpbuf, int* time_limit);
uint8_t message_read_and_transform_payload(int fd, uint8_t* const tmpbuf, uint8_t* cmdbuf, int32_t offset, int32_t* len, uint32_t seed, int* time_limit);
