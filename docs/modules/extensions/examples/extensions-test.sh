#!/bin/sh

./nestable-extension-block-runner.sh | diff --brief - nestable-extension-class-out.html

./nestable-extension-class-runner.sh | diff --brief - nestable-extension-class-out.html

./nestable-extension-object-runner.sh | diff --brief - nestable-extension-object-out.html

./block-collapsible-extension-runner.sh | diff --brief - block-collapsible-extension-out.html

./block-macro-gist-extension-runner.sh | diff --brief - block-macro-gist-extension-out.html

./block-shout-extension-runner.sh | diff --brief - block-shout-extension-out.html

./docinfo-google-analytics-extension-runner.sh | diff --brief - docinfo-google-analytics-extension-out.html

./include-uri-extension-runner.sh | diff --brief - include-uri-extension-out.html

./inline-man-extension-runner.sh | diff --brief - inline-man-extension-out.html

./inline-rfc-link-extension-runner.sh | diff --brief - inline-rfc-link-extension-out.html

./post-footer-extension-runner.sh | diff  --brief - post-footer-extension-out.html

./pre-front-matter-extension-runner.sh | diff --brief - pre-front-matter-extension-out.html

./tree-shell-session-extension-runner.sh | diff --brief - tree-shell-session-extension-out.html
