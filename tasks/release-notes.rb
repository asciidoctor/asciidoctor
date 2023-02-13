# frozen_string_literal: true

require 'time'

old_tz, ENV['TZ'] = ENV['TZ'], 'US/Mountain'
release_date = Time.now.strftime '%Y-%m-%d'
ENV['TZ'] = old_tz

spec = Gem::Specification.load Dir['*.gemspec'].first
gem_name = spec.name
gem_version = spec.version
gem_dist_url = %(https://rubygems.org/gems/#{gem_name})
release_notes_file = 'pkg/release-notes.md'
release_user = ENV['RELEASE_USER'] || 'mojavelinux'
release_beer = ENV['RELEASE_BEER'] || 'TBD'
release_tag = %(v#{gem_version})
previous_tag = (`git -c versionsort.suffix=. -c versionsort.suffix=- ls-remote --tags --refs --sort -v:refname origin`.each_line chomp: true)
  .map {|it| (it.rpartition '/')[-1] }
  .drop_while {|it| it != release_tag }
  .reject {|it| it == release_tag }
  .find {|it| (Gem::Version.new it.slice 1, it.length) < gem_version }
issues_url = spec.metadata['bug_tracker_uri']
repo_url = spec.metadata['source_code_uri']
changelog = (File.readlines 'CHANGELOG.adoc', chomp: true, mode: 'r:UTF-8').reduce nil do |accum, line|
  if line == '=== Details'
    accum.pop
    break accum.join ?\n
  elsif accum
    if line.end_with? '::'
      line = %(### #{line.slice 0, line.length - 2})
    elsif line.start_with? '  * '
      line = line.lstrip
    end
    accum << line unless accum.empty? && line.empty?
  elsif line.start_with? %(== #{gem_version} )
    accum = []
  end
  accum
end

release_notes = <<~EOS.chomp
Write summary...

## Distribution

- [RubyGem (#{gem_name})](#{gem_dist_url})

Asciidoctor is also packaged for [Fedora](https://apps.fedoraproject.org/packages/rubygem-asciidoctor), [Debian](https://packages.debian.org/sid/asciidoctor), [Ubuntu](https://packages.ubuntu.com/search?keywords=asciidoctor), [Alpine Linux](https://pkgs.alpinelinux.org/packages?name=asciidoctor), [OpenSUSE](https://software.opensuse.org/package/rubygem-asciidoctor), and [Homebrew](https://formulae.brew.sh/formula/asciidoctor). You can use the system's package manager to install the package named **asciidoctor**.

## Changelog

#{changelog}

## Release meta

Released on: #{release_date}
Released by: @#{release_user}
Release beer: #{release_beer}

Logs: [resolved issues](#{issues_url}?q=is%3Aissue+label%3A#{release_tag}+is%3Aclosed)#{previous_tag ? %( | [source diff](#{repo_url}/compare/#{previous_tag}...#{release_tag}) | [gem diff](https://my.diffend.io/gems/asciidoctor/#{previous_tag}/#{release_tag})) : ''}

## Credits

A very special thanks to all the **awesome** [supporters of the Asciidoctor OpenCollective campaign](https://opencollective.com/asciidoctor), who provide critical funding for the ongoing development of this project.
EOS

File.write release_notes_file, release_notes, mode: 'w:UTF-8'
