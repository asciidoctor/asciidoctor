#!/bin/sh

# A convenience script to run tests without delays caused by incrementally writing to the terminal buffer.
# This script will execute against all supported Ruby versions if "all" is the first argument to the script.

if [ "$1" = "all" ]; then
  rvm 2.3@asciidoctor-dev,2.4@asciidoctor-dev,2.5@asciidoctor-dev,2.6@asciidoctor-dev,jruby-9.1@asciidoctor-dev,jruby-9.2@asciidoctor-dev "do" ./run-tests.sh
else
  rake test:all > /tmp/asciidoctor-test-results.txt 2>&1; cat /tmp/asciidoctor-test-results.txt
fi
