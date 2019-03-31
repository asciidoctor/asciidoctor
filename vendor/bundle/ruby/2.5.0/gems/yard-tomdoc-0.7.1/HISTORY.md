# RELEASE HISTORY

## 0.7.1 / 2013-02-16

This release add support for "Returns nothing" being translated
into `@return [void]`. And adds support for putting the return
type at the end of the description if no other return clauses are
specificed. This is especially useful for attributes.

Changes:

* Add support for returns nothing.
* Add support for description only return type.


## 0.7.0 / 2013-02-12

New major release uses the new major release of TomParse.
So there you go. Oh, it improves class parsing for `Return`
sections too. That's all.

Changes:

* Upgrade TomParse requirement to 0.4.0+.
* Imporove class parsing for return tags.


## 0.6.0 / 2013-01-22

This new major release adds support for most YARD tags thanks to TomParse's
new support of tag markers. It also fixes a few annoying bugs, such a
options parsing and multi-line paragraph descriptions.

Changes:

* Add support for most YARD tags.
* Fix support for option hashes.
* Fix support for multi-paragraph descriptions.


## 0.5.0 / 2012-06-14

Version 0.8.0 of YARD broke the yard-tomdoc plugin. After some discussion with
Loren Segal, the developer of YARD, he decided that a new API was needed for
plugins like yard-tomdoc. So YARD 0.8.1 was born. This release takes advantage
of the new API. If you are using the latest and greatest version of YARD, you 
need to upgrade to yard-tomdoc 0.5+ too.

Changes:

* Improved support for YARD 0.8.1+.
* Support multiple versions of YARD in a nice way.
* Use @api private tag instead of @private for Internal status.
* Add support for YARD version 0.8+.
* Fixes for Internal and Deprecated marks.
* Fix error for 'Deprecated' description
* Fix Issue #3, Error for 'Internal' description.


## 0.4.0 / 2012-03-04

This major release now uses tomparse gem for parsing TomDoc,
instead of the tomdoc gem. This library only handles parsing
and none of the other features than the tomdoc gem provides,
so it is more suited to yard-tomdoc's needs. In addition,
support for the latest TomDoc specification are included in
this release.

Changes:

* Use tomparse gem for parsing TomDoc.
* Improve support for TomDoc features.


## 0.3.1 | 2011-11-10

This release simply modernizes the build configuration
and adds an systems test. Functionally it has not changed.

Changes:

* Modernize the build configuration.
* Add systems test and integrate Travis CI.


## 0.3.0 | 2011-06-08

Okay,looks like tomdoc is ready to handle the dependency. If there
are any problems with this there is a fallback plugin, `tomdoc-intern`.

Changes:

* Depend on tomdoc proper.
* Add fallback `yard-tomdoc-intern.rb`


## 0.2.1 | 2011-05-23

There is an as-of-yet undetermined issue with running yard-tomdoc under
Ruby 1.9. By depending on an internal copy of TomDoc's TomDoc class we
are able to avoid the problem. So, for now we are removing the dependency
on the `tomdoc` gem until this is fully resolved.

Changes:

* Remove dependency on tomdoc.
* Require internal copy of tomdoc/tomdoc.rb.


## 0.2.0 | 2011-05-22

This is first packaged release of YARD-TomDoc. Some minor improvements
have been made from the original version and the project now actually
depends on the `tomdoc` library.

Changes:

* Depend on `tomdoc` library.
* Support YARD's method return object.
* Fix args issues when missing section.

