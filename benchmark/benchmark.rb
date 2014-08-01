#!/usr/bin/env ruby

=begin

Use this script to monitor changes in performance when making code changes to Asciidoctor.

 $ ruby benchmark.rb <benchmark-name> <repeat>

The most common benchmark is the userguide-loop.
It will download the AsciiDoc User Guide automatically the first time, then convert it in memory.
Running it 10 times provides a good picture.

 $ ruby benchmark.rb userguide-loop 10

Only worry about the relative change to the numbers before and after the code change.
Absolute times are highly dependent on the capabilities of the machine the the version of Ruby.

To get the best results under MRI, tune Ruby using environment variables as follows:

.Ruby < 2.1
 $ RUBY_GC_MALLOC_LIMIT=90000000 RUBY_FREE_MIN=650000 ruby benchmark.rb userguide-loop 10

.Ruby >= 2.1
 $ RUBY_GC_MALLOC_LIMIT=128000000 RUBY_GC_OLDMALLOC_LIMIT=128000000 RUBY_GC_HEAP_INIT_SLOTS=800000 RUBY_GC_HEAP_FREE_SLOTS=800000 RUBY_GC_HEAP_GROWTH_MAX_SLOTS=250000 RUBY_GC_HEAP_GROWTH_FACTOR=1.5 ruby benchmark.rb userguide-loop 10

Asciidoctor starts with ~ 12,500 objects, adds ~ 300,000 each run, so tune RUBY_GC_HEAP_* accordingly

Execute Ruby using the `--disable=gems` flag to speed up the initial load time, as shown below:

 $ ruby --disable=gems ...

=end

require 'benchmark'
include Benchmark

bench = ARGV[0]
$repeat = ARGV[1].to_i || 10000

if bench.nil?
  raise 'You must specify a benchmark to run.'
end

def fetch_userguide
  require 'open-uri'
  userguide_uri = 'https://raw.githubusercontent.com/asciidoc/asciidoc/d43faae38c4a8bf366dcba545971da99f2b2d625/doc/asciidoc.txt'
  customers_uri = 'https://raw.githubusercontent.com/asciidoc/asciidoc/d43faae38c4a8bf366dcba545971da99f2b2d625/doc/customers.csv'
  userguide_content = open(userguide_uri) {|fd2| fd2.read }
  customers_content = open(customers_uri) {|fd2| fd2.read }
  File.open('sample-data/userguide.adoc', 'w') {|fd1| fd1.write userguide_content }
  File.open('sample-data/customers.csv', 'w') {|fd1| fd1.write customers_content }
end

case bench

=begin
# benchmark template

when 'name'

  sample = 'value'

  Benchmark.bmbm(12) {|bm|
    bm.report('operation a') { $repeat.times { call_a_on sample } }
    bm.report('operation b') { $repeat.times { call_b_on sample } }
  }
=end

when 'userguide'
  require '../lib/asciidoctor.rb'
  Asciidoctor::Compliance.markdown_syntax = false
  Asciidoctor::Compliance.shorthand_property_syntax = false if Asciidoctor::VERSION > '0.1.4'
  sample_file = ENV['BENCH_TEST_FILE'] || 'sample-data/userguide.adoc'
  backend = ENV['BENCH_BACKEND'] || 'html5'
  fetch_userguide if sample_file == 'sample-data/userguide.adoc' && !(File.exist? sample_file)
  result = Benchmark.bmbm {|bm|
    bm.report(%(Convert #{sample_file} (x#{$repeat}))) {
      $repeat.times {
        Asciidoctor.render_file sample_file, :backend => backend, :safe => Asciidoctor::SafeMode::SAFE, :eruby => 'erubis', :header_footer => true, :to_file => false, :attributes => {'linkcss' => '', 'toc' => nil, 'numbered' => nil, 'icons' => nil, 'compat-mode' => 'legacy'}
      }
    }
  }
  # prints average for real run
  puts %(>avg: #{result.first.real / $repeat})

when 'userguide-loop'
  require '../lib/asciidoctor.rb'
  GC.start
  Asciidoctor::Compliance.markdown_syntax = false
  Asciidoctor::Compliance.shorthand_property_syntax = false if Asciidoctor::VERSION > '0.1.4'
  sample_file = ENV['BENCH_TEST_FILE'] || 'sample-data/userguide.adoc'
  backend = ENV['BENCH_BACKEND'] || 'html5'
  fetch_userguide if sample_file == 'sample-data/userguide.adoc' && !(File.exist? sample_file)

  best = nil
  2.times.each do
    outer_start = Time.now
    (1..$repeat).each do
      inner_start = Time.now
      Asciidoctor.render_file sample_file, :backend => backend, :safe => Asciidoctor::SafeMode::SAFE, :eruby => 'erubis', :header_footer => true, :to_file => false, :attributes => {'linkcss' => '', 'toc' => nil, 'numbered' => nil, 'icons' => nil, 'compat-mode' => 'legacy'}
      puts (elapsed = Time.now - inner_start)
      best = (best ? [best, elapsed].min : elapsed)
    end
    puts %(Run Total: #{Time.now - outer_start})
  end
  puts %(Best Time: #{best})

when 'mdbasics-loop'
  require '../lib/asciidoctor.rb'
  GC.start
  sample_file = ENV['BENCH_TEST_FILE'] || 'sample-data/userguide.adoc'
  backend = ENV['BENCH_BACKEND'] || 'html5'

  best = nil
  2.times do
    outer_start = Time.now
    (1..$repeat).each do
      inner_start = Time.now
      Asciidoctor.render_file sample_file, :backend => backend, :safe => Asciidoctor::SafeMode::SAFE, :header_footer => false, :to_file => false, :attributes => {'linkcss' => '', 'idprefix' => '', 'idseparator' => '-', 'showtitle' => ''}
      puts (elapsed = Time.now - inner_start)
      best = (best ? [best, elapsed].min : elapsed)
    end
    puts %(Run Total: #{Time.now - outer_start})
  end
  puts %(Best Time: #{best})

end
