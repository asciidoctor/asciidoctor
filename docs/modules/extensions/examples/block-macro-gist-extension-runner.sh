#!/bin/sh

#tag::runner[]
echo \
'.My Gist
gist::123456[]' \
| asciidoctor -s -r ./block-macro-gist-extension.rb -
#end::runner[]