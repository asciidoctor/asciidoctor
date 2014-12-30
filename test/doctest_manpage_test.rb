# encoding: UTF-8
unless defined? ASCIIDOCTOR_PROJECT_DIR
  $: << File.dirname(__FILE__); $:.uniq!
  require 'test_helper'
end
require 'asciidoctor/doctest/manpage/examples_suite'

class TestManPage < DocTest::Test
  converter_opts backend_name: 'manpage'
  generate_tests! DocTest::ManPage::ExamplesSuite
end
