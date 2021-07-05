$ErrorActionPreference = 'Stop'
refreshenv
gem install asciidoctor -v 2.0.12

Write-Warning @'
Usage: asciidoctor [OPTION]... FILE...

Translate the AsciiDoc source FILE or FILE(s) into the specified backend output format (e.g., HTML 5, DocBook 5, etc.)

> asciidoctor document.adoc

'@
