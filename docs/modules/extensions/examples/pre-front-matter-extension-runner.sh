#!/bin/sh

#tag::runner[]
asciidoctor -s -r ./pre-front-matter-extension.rb ./pre-front-matter-extension-sample.adoc
#end::runner[]
