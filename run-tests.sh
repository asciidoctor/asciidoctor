#!/bin/bash

# A convenience script to run tests without delays caused by incrementally writing to the terminal buffer.

GEM_PATH=$(bundle exec ruby -e "puts ENV['GEM_HOME']")
CONSOLE_OUTPUT=$(rake test:all 2>&1)
echo "$CONSOLE_OUTPUT"
