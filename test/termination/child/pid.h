#ifndef PID_H_
#define PID_H_
#pragma once

#ifdef _WIN32
#include <process.h>

int get_pid()
{
  return _getpid();
}

#else //_WIN32 not defined
#include <sys/types.h>
#include <unistd.h>

int get_pid()
{
  return (int)getpid();
}

#endif //_WIN32

#endif //PID_H_
