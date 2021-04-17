#!/bin/sh

#tag::runner[]
asciidoctor -s -r ./inline-man-extension.rb ./inline-man-extension-sample.adoc
#end::runner[]