project(Executor C)
cmake_minimum_required(VERSION 2.8)

if(NOT((${CMAKE_GENERATOR} STREQUAL "Unix Makefiles") OR (${CMAKE_GENERATOR} STREQUAL "MSYS Makefiles") OR (${CMAKE_GENERATOR} STREQUAL "MinGW Makefiles")))
    message(FATAL_ERROR "Chosen generator is not supported for this project")
endif()

message(STATUS "Building for ${CMAKE_SYSTEM_NAME}. Processor architecture is ${CMAKE_SYSTEM_PROCESSOR}")

#set some custom options and default values
set(ARCHSUFFIX ".${CMAKE_SYSTEM_PROCESSOR}")

if(NOT CMAKE_BUILD_TYPE)
 set(CMAKE_BUILD_TYPE "Release")
endif(NOT CMAKE_BUILD_TYPE)

#set defaults
set(EXELINKFLAGS "")
set(OPTFLAGS "")

#setup RPATH and build directories
set(CMAKE_SKIP_BUILD_RPATH FALSE)
set(CMAKE_USE_RELATIVE_PATHS TRUE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)

set(CMAKE_INSTALL_RPATH "./lib${ARCHSUFFIX}")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/build/lib${ARCHSUFFIX}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/build/lib${ARCHSUFFIX}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/build")

file(MAKE_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
file(MAKE_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})

#print status
message(STATUS "Current build configuration:")
message(STATUS "CMAKE_GENERATOR=${CMAKE_GENERATOR}")
message(STATUS "CMAKE_SOURCE_DIR=${CMAKE_SOURCE_DIR}")
message(STATUS "CMAKE_BINARY_DIR=${CMAKE_BINARY_DIR}")
message(STATUS "CMAKE_ARCHIVE_OUTPUT_DIRECTORY=${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}")
message(STATUS "CMAKE_LIBRARY_OUTPUT_DIRECTORY=${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
message(STATUS "CMAKE_RUNTIME_OUTPUT_DIRECTORY=${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")

include_directories("${CMAKE_BINARY_DIR}")

#set flags for gcc
if(CMAKE_COMPILER_IS_GNUCC)
 #platform dependent gcc flags
 set(OPTFLAGS "-fpic -pedantic")
 #general compiler flags for gcc compiler
 ##You can enable additional warnings for paranoics: -Wunsuffixed-float-constants -Wpadded
 set(CMAKE_C_FLAGS "-std=gnu99 -Wall -Wextra -Wshadow -Wstrict-overflow=5 -Wwrite-strings -Winit-self -Wmissing-include-dirs -Wbad-function-cast -Wc++-compat -Wcast-qual -Wcast-align -Wconversion -Wlogical-op -Wstrict-prototypes -Wold-style-definition -Wmissing-prototypes -Wmissing-declarations -Wpacked -Wredundant-decls -Wnested-externs -Winline -Wdisabled-optimization -Woverlength-strings -Wfloat-equal -Wswitch-default ${OPTFLAGS}")
 #set build-type dependent additional flags
 set(CMAKE_C_FLAGS_RELEASE "-O2 -DNDEBUG")
 set(CMAKE_C_FLAGS_DEBUG "-DDEBUG -ggdb")
 add_definitions(-D_GNU_SOURCE)
 set(EXELINKFLAGS "-Wl,-rpath-link,'${CMAKE_LIBRARY_OUTPUT_DIRECTORY}'")
endif()

#check include files
include(CheckIncludeFile)
include(CheckSymbolExists)
check_include_file(inttypes.h HAVE_INTTYPES_H)
check_include_file(stdint.h HAVE_STDINT_H)
check_include_file(stddef.h HAVE_STDDEF_H)
check_include_file(stdarg.h HAVE_STDARG_H)
if(NOT(HAVE_STDARG_H))
 message(FATAL_ERROR "C header file stdarg.h not available for your platform. Cannot proceed.")
endif()
check_include_file(ctype.h HAVE_CTYPE_H)
check_symbol_exists(isdigit ctype.h HAVE_ISDIGIT)
if((NOT(HAVE_CTYPE_H)) OR (NOT(HAVE_ISDIGIT)))
 message(FATAL_ERROR "C header file ctype.h or isdigit() function not available for your platform. Cannot proceed.")
endif()

check_include_file(sys/types.h HAVE_SYSTYPES_H)
check_include_file(sys/stat.h HAVE_SYSSTAT_H)
check_include_file(sys/wait.h HAVE_SYSWAIT_H)
check_include_file(sys/fcntl.h HAVE_FNCTL_H)
check_include_file(sys/time.h HAVE_SYSTIME_H)
check_include_file(sys/ioctl.h HAVE_SYSIOCTL_H)

check_include_file(stdbool.h HAVE_STDBOOL_H)
check_include_file(poll.h HAVE_POLL_H)
check_include_file(signal.h HAVE_SIGNAL_H)
check_include_file(unistd.h HAVE_UNISTD_H)
check_include_file(errno.h HAVE_ERRNO_H)
check_include_file(dirent.h HAVE_DIRENT_H)
check_include_file(utmp.h HAVE_UTMP_H)

if(NOT(HAVE_SYSSTAT_H))
 message(FATAL_ERROR "C header file sys/types.h not available for your platform. Cannot proceed.")
endif()
if(NOT(HAVE_SYSTYPES_H))
 message(FATAL_ERROR "C header file sys/types.h not available for your platform. Cannot proceed.")
endif()
if(NOT(HAVE_SYSWAIT_H))
 message(FATAL_ERROR "C header file sys/wait.h not available for your platform. Cannot proceed.")
endif()
if(NOT(HAVE_SIGNAL_H))
 message(FATAL_ERROR "C header file signal.h not available for your platform. Cannot proceed.")
endif()
if(NOT(HAVE_UNISTD_H))
 message(FATAL_ERROR "C header file unistd.h not available for your platform. Cannot proceed.")
endif()
if(NOT(HAVE_FNCTL_H))
 message(FATAL_ERROR "C header file sys/fcntl.h not available for your platform. Cannot proceed.")
endif()
if(NOT(HAVE_SYSTIME_H))
 message(FATAL_ERROR "C header file sys/time.h not available for your platform. Cannot proceed.")
endif()
if(NOT(HAVE_ERRNO_H))
 message(FATAL_ERROR "C header file sys/time.h not available for your platform. Cannot proceed.")
endif()
if(NOT(HAVE_SYSIOCTL_H))
 message(FATAL_ERROR "C header file sys/ioctl.h not available for your platform. Cannot proceed.")
endif()
if(NOT(HAVE_DIRENT_H))
 message(FATAL_ERROR "C header file dirent.h not available for your platform. Cannot proceed.")
endif()
if(NOT(HAVE_UTMP_H))
 message(FATAL_ERROR "C header file utmp.h not available for your platform. Cannot proceed.")
endif()


#check for pthread support
set(CMAKE_THREAD_PREFER_PTHREAD 1)
include(FindThreads)
if(CMAKE_USE_PTHREADS_INIT)
 check_include_file(pthread.h HAVE_PTHREAD_H)
endif()
if(NOT(HAVE_PTHREAD_H))
 message(FATAL_ERROR "C header file pthread.h not available for your platform!")
else()
 message(STATUS "CMAKE_THREAD_LIBS_INIT = ${CMAKE_THREAD_LIBS_INIT}")
endif(NOT(HAVE_PTHREAD_H))

#save module configuration to config.h
configure_file(config.h.in config.h)

#qt creator trick
if(CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES)
 include_directories("${CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES}")
endif(CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES)

#test util
add_executable(test.bin${ARCHSUFFIX} helper_macro.h logger.c test.c)
set_property(TARGET test.bin${ARCHSUFFIX} PROPERTY LINK_FLAGS "-static")
target_link_libraries(test.bin${ARCHSUFFIX} ${CMAKE_THREAD_LIBS_INIT})

#new executor util, static
add_executable(executor helper_macro.h cmd_defs.h comm_helper.c hash.c message.c logger.c pid_list.c executor.c)
set_property(TARGET executor PROPERTY LINK_FLAGS "-static")
target_link_libraries(executor ${CMAKE_THREAD_LIBS_INIT} -lutil)

#commander util, static
add_executable(commander helper_macro.h cmd_defs.h comm_helper.c hash.c message.c logger.c commander.c)
set_property(TARGET commander PROPERTY LINK_FLAGS "-static")
target_link_libraries(commander ${CMAKE_THREAD_LIBS_INIT})
