#!/bin/sh

# A convenience script to run tests without delays caused by incrementally writing to the terminal buffer
rake > /tmp/asciidoctor-test-results.txt 2>&1; cat /tmp/asciidoctor-test-results.txt
