#!/bin/sh

#tag::runner[]
echo \
'= Not-copyrightable

There is no copyrightable expression here.' \
| asciidoctor -r ./post-footer-extension.rb -a linkcss=true -a reproducible=true -
#end::runner[]
