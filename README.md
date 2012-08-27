Asciidoctor
===========

Asciidoctor is a pure-ruby processor for turning
[Asciidoc](http://www.methods.co.nz/asciidoc/index.html) documents
into HTML (and, eventually, other formats perhaps).

Asciidoctor uses simple built-in ERB templates to style the output in
a way that roughly matches the default HTML output of the native
Python processor. You can override this behavior by providing
[Tilt]-compatible templates. See the Usage section for more details.

Asciidoctor currently works with Ruby 1.8.7 and 1.9.3, though I don't
know of any reason it shouldn't work with more exotic Ruby versions,
and would welcome help in testing that out.

The initial code from which Asciidoctor started was from the [Git SCM
site repo][gitscm-next].

[gitscm-next]: https://github.com/github/gitscm-next

# Installation

NOTE: This gem is very immature, and as yet only supports a small
subset of Asciidoc features.  Thus, you should only use it if you have
a high tolerance for bugs, failures, and generally bad and intemperate
behavior.

To install the gem:

    gem install 'asciidoctor'

Or if you prefer bundler:

    bundle install 'asciidoctor'

# Usage

To render a file of Asciidoc-marked-up text to html

    lines = File.readlines("your_file.asc")
    doc = Asciidoctor::Document.new(lines)
    html = doc.render
    File.open("your_file.html", "w+") do |file|
      file.puts html
    end

Render an Asciidoc-formatted string

    doc = Asciidoctor::Document.new("*This* is it.")
    puts doc.render

Asciidoctor allows you to override the default template used to render
almost any individual Asciidoc elements. If you provide a directory of
[Tilt]-compatible templates, named in a way Asciidoctor can figure out
which template goes with which element, Asciidoctor will use the
templates in this directory instead of its built-in templates for any
elements for which it finds a matching template.  It will use its
default templates for everything else.

    doc = Asciidoctor::Document.new("*This* is it.", :template_dir => 'templates')
    puts doc.render

The Document and Section templates should begin with `document.` and
`section.`, respectively. The file extension will depend on which
Tilt-compatible format you've chosen. For ERB, they would be
`document.html.erb` and `section.html.erb`, for instance.

Specific elements, like a Paragraph or Anchor, would begin with
`section_<element>.`. So to override the default Paragraph template
with an ERB template you'd put a file called
`section_paragraph.html.erb` in the template directory you pass in to
`Document.new`.

For more usage examples, see the test suite.

[Tilt]: https://github.com/rtomayko/tilt

## Contributing
In the spirit of [free software][free-sw], **everyone** is encouraged to help
improve this project.

[free-sw]: http://www.fsf.org/licensing/essays/free-sw.html

Here are some ways *you* can contribute:

* by using alpha, beta, and prerelease versions
* by reporting bugs
* by suggesting new features
* by writing or editing documentation
* by writing specifications
* by writing code (**no patch is too small**: fix typos, add comments, clean up
  inconsistent whitespace)
* by refactoring code
* by fixing [issues][]
* by reviewing patches

[issues]: https://github.com/erebor/asciidoctor/issues

## Submitting an Issue
We use the [GitHub issue tracker][issues] to track bugs and
features. Before submitting a bug report or feature request, check to
make sure it hasn't already been submitted. When submitting a bug
report, please include a [Gist][] that includes any details that may
help reproduce the bug, including your gem version, Ruby version, and
operating system.

Most importantly, since asciidoctor is a text processor, reproducing
most bugs requires that we have some snippet of text on which
asciidoctor exhibits the bad behavior.

An ideal bug report would include a pull request with failing
specs.

[gist]: https://gist.github.com/

## Submitting a Pull Request
1. [Fork the repository.][fork]
2. [Create a topic branch.][branch]
3. Add tests for your unimplemented feature or bug fix.
4. Run `bundle exec rake`. If your tests pass, return to step 3.
5. Implement your feature or bug fix.
6. Run `bundle exec rake`. If your tests fail, return to step 5.
7. Add documentation for your feature or bug fix.
8. If your changes are not 100% documented, go back to step 7.
9. Add, commit, and push your changes.
10. [Submit a pull request.][pr]

[fork]: http://help.github.com/fork-a-repo/
[branch]: http://learn.github.com/p/branching.html
[pr]: http://help.github.com/send-pull-requests/

## Supported Ruby Versions
This library aims to support the following Ruby implementations:

* Ruby 1.8.7
* Ruby 1.9.3

If something doesn't work on one of these interpreters, it should be
considered a bug.

If you would like this library to support another Ruby version, you
may volunteer to be a maintainer. Being a maintainer entails making
sure all tests run and pass on that implementation. When something
breaks on your implementation, you will be personally responsible for
providing patches in a timely fashion. If critical issues for a
particular implementation exist at the time of a major release,
support for that Ruby version may be dropped.

## Copyright
Copyright (c) 2012 Ryan Waldron.
See [LICENSE][] for details.

[license]: https://github.com/erebor/asciidoctor/blob/master/LICENSE
