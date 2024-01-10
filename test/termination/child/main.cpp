#include <iostream>
#include <chrono>
#include <thread>
#include "pid.h"

using namespace std;

int main(int argc, char** argv)
{
  using namespace std::chrono_literals;
  int pid = get_pid();
  cerr << pid << " started" << endl;
  auto time = 10s;
  cerr << pid << " sleep for " << time.count() << "s" << endl;
  std::this_thread::sleep_for(time);
  cerr << pid << " finished" << endl;
  return 0;
}
