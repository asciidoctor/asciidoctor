#!/bin/sh

#tag::runner[]
echo \
'.Show JSON
[collapsible,json]
----
{
   "foo": "bar"
}
----' \
| asciidoctor -s -r ./block-collapsible-extension.rb -
#end::runner[]