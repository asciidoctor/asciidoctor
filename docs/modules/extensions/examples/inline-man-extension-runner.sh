#!/bin/sh

#tag::runner[]
echo \
'See man:gittutorial[7] to get started.
' \
| asciidoctor -s -r ./inline-man-extension.rb -
#end::runner[]