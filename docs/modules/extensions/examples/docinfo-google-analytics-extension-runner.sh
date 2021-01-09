#!/bin/sh

#tag::runner[]
echo \
'= Silly Page

Who would look at this content?

' \
| asciidoctor -r ./docinfo-google-analytics-extension.rb -a google-analytics-account=UA-ABCXYZ123  -a linkcss=true -a reproducible=true -
#end::runner[]