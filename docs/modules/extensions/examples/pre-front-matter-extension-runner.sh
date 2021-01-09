#!/bin/sh

#tag::runner[]
echo \
'tags: [announcement, website]
---
= Document Title

content

[subs=+attributes]
.Captured front matter
....
---
{front-matter}
---
....
' \
| asciidoctor -s -r ./pre-front-matter-extension.rb -
#end::runner[]
