# Release History

## 0.4.2 / 2013-02-15

This release fixes description and argument parsing when
a visibility indicator is used.

Changes:

* Fix desc/arguments parsing given indicator.


## 0.4.1 / 2013-02-14

This release fixes example parsing.

Changes:

* Handle variable indention in examples.
* Do not remove newlines for single example.


## 0.4.0 / 2013-02-10

For this release, the document parser has been substantially refactored.
It should be both more robust and more flexible. Arguments can now
have an optional `Arguments` heading, and the arguments list can be
indented. A new `Options` section is supported to handle Ruby 2.0 style
keyword options. Tag labels ony need to be capitalized. They no longer
have to be all-caps. And lastly, the `Signature` section has been
repurposed for describing variant *parameter signatures*, not dynamic
methods. As such `signature_fields` has been deprecated. Yes, these
are additions and some deviation from the original TomDoc spec, but
when purely conceptual specs go into practice they have a tendency to 
adapt to practical requirements.

Changes:

* Refactor document parser.
* Add support for optional Arguments section header.
* Add support for Options section.
* Modify purpose of Signatures section.
* Deprecate signature field list.
* Tag labels only need to be capitialized, not all-caps.


## 0.3.0 / 2012-01-21

This release fixes a bug which prevented descriptions from having
multiple paragraphs. In addition it adds support for section tags.
See the README for more information on tags.

Changes:

* Fix multi-paragraph description parsing.
* Add support for tags.
* Fix support for option hashes. (Jonas Oberschweiber)


## 0.2.1 / 2012-04-30

This release fixes indention with multi-line examples.

Changes:

* Correctly indent multiline code examples.
* Swtich to Citron for testing.


## 0.2.0 / 2012-03-07

This release improves support of TomDoc, in particular, named parameters. It also
fixes a bug with appending to argument and option descriptions.

Changes:

* Ass support for named parameters.
* Fix appending to argument description issue.


## 0.1.0 / 2012-03-04

TomParse is stand-alone TomDoc parser, spun-off and rewritten from the original
tomdoc.rb code from the defunkt/tomdoc project. Having a stand-alone project
just for the parser, makes it more convenient for other libraries to make use,
including, eventually, the original tomdoc project itself.

Changes:

* Happy Birthday.

