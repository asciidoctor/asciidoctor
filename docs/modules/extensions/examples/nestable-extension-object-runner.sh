#!/bin/sh

#tag::runner[]
echo \
'[barblock,foo]
====
Inside the Bar Block
[bazblock,bax]
======
Inside the Baz Block
======
====' \
| asciidoctor -s -r ./nestable-extension-object.rb -
#end::runner[]