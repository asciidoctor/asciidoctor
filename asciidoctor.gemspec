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
  s.version           = '0.0.9'
  s.date              = '2013-01-16'
  s.rubyforge_project = 'asciidoctor'

  ## Make sure your summary is short. The description may be as long
  ## as you like.
  s.summary     = "Pure Ruby Asciidoc to HTML rendering."
  s.description = "A pure Ruby processor to turn Asciidoc-formatted documents into HTML (and, eventually, other formats perhaps)."

  ## List the primary authors. If there are a bunch of authors, it's probably
  ## better to set the email to an email list or something. If you don't have
  ## a custom homepage, consider using your GitHub URL or the like.
  s.authors  = ["Ryan Waldron", "Dan Allen", "Jeremy McAnally"]
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

  ## List your development dependencies here. Development dependencies are
  ## those that are only needed during development
  s.add_development_dependency('coderay')
  s.add_development_dependency('erubis')
  s.add_development_dependency('htmlentities')
  s.add_development_dependency('mocha')
  s.add_development_dependency('nokogiri')
  s.add_development_dependency('pending')
  s.add_development_dependency('rake')
  s.add_development_dependency('tilt')

  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
    Gemfile
    LICENSE
    README.asciidoc
    Rakefile
    asciidoctor.gemspec
    bin/asciidoctor
    lib/asciidoctor.rb
    lib/asciidoctor/abstract_block.rb
    lib/asciidoctor/abstract_node.rb
    lib/asciidoctor/attribute_list.rb
    lib/asciidoctor/backends/base_template.rb
    lib/asciidoctor/backends/docbook45.rb
    lib/asciidoctor/backends/html5.rb
    lib/asciidoctor/block.rb
    lib/asciidoctor/callouts.rb
    lib/asciidoctor/debug.rb
    lib/asciidoctor/document.rb
    lib/asciidoctor/errors.rb
    lib/asciidoctor/inline.rb
    lib/asciidoctor/lexer.rb
    lib/asciidoctor/list_item.rb
    lib/asciidoctor/reader.rb
    lib/asciidoctor/renderer.rb
    lib/asciidoctor/section.rb
    lib/asciidoctor/substituters.rb
    lib/asciidoctor/table.rb
    lib/asciidoctor/version.rb
    noof.rb
    test/attributes_test.rb
    test/blocks_test.rb
    test/document_test.rb
    test/fixtures/asciidoc.txt
    test/fixtures/asciidoc_index.txt
    test/fixtures/ascshort.txt
    test/fixtures/dot.gif
    test/fixtures/encoding.asciidoc
    test/fixtures/include-file.asciidoc
    test/fixtures/list_elements.asciidoc
    test/fixtures/tip.gif
    test/headers_test.rb
    test/lexer_test.rb
    test/links_test.rb
    test/lists_test.rb
    test/paragraphs_test.rb
    test/preamble_test.rb
    test/reader_test.rb
    test/renderer_test.rb
    test/substitutions_test.rb
    test/tables_test.rb
    test/test_helper.rb
    test/text_test.rb
  ]
  # = MANIFEST =

  ## Test files will be grabbed from the file list. Make sure the path glob
  ## matches what you actually use.
  s.test_files = s.files.select { |path| path =~ /^test\/.*_test\.rb/ }
end
