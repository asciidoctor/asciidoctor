#!/bin/bash

# A convenience script to run tests without delays caused by incrementally writing to the terminal buffer.

CONSOLE_OUTPUT=$(bundle exec rake test:all 2>&1)
echo "$CONSOLE_OUTPUT"
