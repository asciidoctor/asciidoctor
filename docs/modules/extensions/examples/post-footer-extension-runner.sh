#!/bin/sh

#tag::runner[]
asciidoctor -r ./post-footer-extension.rb -a linkcss=true -a reproducible=true ./post-footer-extension-sample.adoc
#end::runner[]
