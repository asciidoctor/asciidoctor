#!/bin/sh

#tag::runner[]
echo \
'[nestable,foo]
====
Inside the Nestable Open Block
====' \
| asciidoctor -s -r ./nestable-extension-block.rb -
#end::runner[]