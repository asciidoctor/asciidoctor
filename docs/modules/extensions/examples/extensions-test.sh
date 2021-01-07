#!/bin/sh

./nestable-extension-block-runner.sh | diff --brief - nestable-extension-class-out.html

./nestable-extension-class-runner.sh | diff --brief - nestable-extension-class-out.html

./nestable-extension-object-runner.sh | diff --brief - nestable-extension-object-out.html

./rfc-link-extension-inline-runner.sh | diff --brief - rfc-link-extension-inline-out.html

