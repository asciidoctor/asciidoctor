## This is the rakegem gemspec template. Make sure you read and understand
## all of the comments. Some sections require modification, and others can
## be deleted if you don't need them. Once you understand the contents of
## this file, feel free to delete any comments that begin with two hash marks.
## You can find comprehensive Gem::Specification documentation, at
## http://docs.rubygems.org/read/chapter/20
Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'

  ## Leave these as is they will be modified for you by the rake gemspec task.
  ## If your rubyforge_project name is different, then edit it and comment out
  ## the sub! line in the Rakefile
  s.name              = 'asciidoctor'
  s.version           = '0.0.7'
  s.date              = '2012-12-17'
  s.rubyforge_project = 'asciidoctor'

  ## Make sure your summary is short. The description may be as long
  ## as you like.
  s.summary     = "Pure Ruby Asciidoc to HTML rendering."
  s.description = "A pure Ruby processor to turn Asciidoc-formatted documents into HTML (and, eventually, other formats perhaps)."

  ## List the primary authors. If there are a bunch of authors, it's probably
  ## better to set the email to an email list or something. If you don't have
  ## a custom homepage, consider using your GitHub URL or the like.
  s.authors  = ["Ryan Waldron", "Jeremy McAnally"]
  s.email    = 'rew@erebor.com'
  s.homepage = 'http://github.com/erebor/asciidoctor'

  ## This gets added to the $LOAD_PATH so that 'lib/NAME.rb' can be required as
  ## require 'NAME.rb' or'/lib/NAME/file.rb' can be as require 'NAME/file.rb'
  s.require_paths = %w[lib]

  ## If your gem includes any executables, list them here.
  s.executables = ["asciidoctor"]

  ## Specify any RDoc options here. You'll want to add your README and
  ## LICENSE files to the extra_rdoc_files list.
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[LICENSE]

  ## List your runtime dependencies here. Runtime dependencies are those
  ## that are needed for an end user to actually USE your code.
  s.add_dependency('tilt')

  ## List your development dependencies here. Development dependencies are
  ## those that are only needed during development
  s.add_development_dependency('mocha')
  s.add_development_dependency('nokogiri')
  s.add_development_dependency('htmlentities')
  s.add_development_dependency('pending')

  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
    LICENSE
    README.asciidoc
    Rakefile
    asciidoctor.gemspec
    bin/asciidoctor
    lib/asciidoctor.rb
    lib/asciidoctor/block.rb
    lib/asciidoctor/debug.rb
    lib/asciidoctor/document.rb
    lib/asciidoctor/errors.rb
    lib/asciidoctor/lexer.rb
    lib/asciidoctor/list_item.rb
    lib/asciidoctor/reader.rb
    lib/asciidoctor/render_templates.rb
    lib/asciidoctor/renderer.rb
    lib/asciidoctor/section.rb
    lib/asciidoctor/string.rb
    lib/asciidoctor/version.rb
    noof.rb
    test/attributes_test.rb
    test/document_test.rb
    test/fixtures/asciidoc.txt
    test/fixtures/asciidoc_index.txt
    test/fixtures/ascshort.txt
    test/fixtures/list_elements.asciidoc
    test/headers_test.rb
    test/lexer_test.rb
    test/links_test.rb
    test/lists_test.rb
    test/paragraphs_test.rb
    test/preamble_test.rb
    test/reader_test.rb
    test/test_helper.rb
    test/text_test.rb
  ]
  # = MANIFEST =

  ## Test files will be grabbed from the file list. Make sure the path glob
  ## matches what you actually use.
  s.test_files = s.files.select { |path| path =~ /^test\/.*_test\.rb/ }
end
