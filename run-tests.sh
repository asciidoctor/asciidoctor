#!/bin/sh

# A convenience script to run tests without delays caused by incrementally writing to the terminal buffer.
# This script will execute against all supported Ruby versions if "all" is the first argument to the script.

if [ "$1" = "all" ]; then
  rvm 2.3,2.6,jruby-9.2 "do" ./run-tests.sh
else
  GEM_PATH=$(bundle exec ruby -e "puts ENV['GEM_HOME']")
  CONSOLE_OUTPUT=$(rake test:all 2>&1)
  echo "$CONSOLE_OUTPUT"
fi
