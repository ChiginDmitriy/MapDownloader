#ifndef RUNNER_AUX_H
#define RUNNER_AUX_H

#include <utility> // std::pair
#include <string>  // std::string

typedef std::pair<std::string, std::string> ParseResult;

ParseResult parseResult(int argc, char *const argv[]);
void doAllWork(const ParseResult &parseResult);
  

#endif // RUNNER_AUX_H
