#!/bin/sh

#tag::runner[]
asciidoctor -r ./docinfo-google-analytics-extension.rb -a google-analytics-account=UA-ABCXYZ123  -a linkcss=true -a reproducible=true ./docinfo-google-analytics-extension-sample.adoc
#end::runner[]