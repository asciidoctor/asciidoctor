#!/bin/sh

#tag::runner[]
echo \
' $ echo "Hello, World!"
 > Hello, World!

 $ gem install asciidoctor
 ' \
| asciidoctor -s -r ./tree-shell-session-extension.rb - --trace
#end::runner[]
