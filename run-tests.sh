#!/bin/sh

# A convenience script to run tests without delays caused by incrementally writing to the terminal buffer.
# This script will execute against all supported Ruby versions if "all" is the first argument to the script.

if [ "$1" = "all" ]; then
  rvm 1.8@asciidoctor-dev,jruby@asciidoctor-dev,rbx@asciidoctor-dev,1.9@asciidoctor-dev,2.0@asciidoctor-dev,2.1@asciidoctor-dev "do" ./run-tests.sh
else
  rake > /tmp/asciidoctor-test-results.txt 2>&1; cat /tmp/asciidoctor-test-results.txt
fi
