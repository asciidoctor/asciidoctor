#!/bin/sh

#tag::runner[]
echo \
'= Standards are Funny

Check out for example RFC 1882 at Christmas, RFC1927 when I forget the space.
Not to mention RFC 2549, a personal favorite.' \
| asciidoctor -s -r ./rfc-link-extension-inline.rb -
#end::runner[]
