#!/bin/sh

#tag::runner[]
echo \
'
.Gemfile
[source,ruby]
----
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/Gemfile[]
----
' \
| asciidoctor -s -r ./include-uri-extension.rb -
#end::runner[]