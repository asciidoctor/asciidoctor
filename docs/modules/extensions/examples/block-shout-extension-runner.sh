#!/bin/sh

#tag::runner[]
echo \
'[shout]
The time is now. Get a move on.

[shout,4]
I mean it.
' \
| asciidoctor -s -r ./block-shout-extension.rb -
#end::runner[]