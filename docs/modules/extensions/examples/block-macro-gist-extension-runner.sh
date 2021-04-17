#!/bin/sh

#tag::runner[]
asciidoctor -s -r ./block-macro-gist-extension.rb ./block-macro-gist-extension-sample.adoc
#end::runner[]