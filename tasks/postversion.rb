# frozen_string_literal: true

release_version = ENV['RELEASE_VERSION']
major_minor_version = ((release_version.split '.').slice 0, 2).join '.'
prerelease = (release_version.count '[a-z]') > 0 ? %(.#{(release_version.split '.', 3)[-1]}) : nil

changelog_file = 'CHANGELOG.adoc'
antora_file = 'docs/antora.yml'

changelog_contents = File.readlines changelog_file, mode: 'r:UTF-8'
last_release_idx = changelog_contents.index {|l| (l.start_with? '== ') && (%r/^== \d/.match? l) }
changelog_contents.insert last_release_idx, <<~END
== Unreleased

_No changes since previous release._

END

antora_contents = (File.readlines antora_file, mode: 'r:UTF-8').map do |l|
  if l.start_with? 'prerelease: '
    %(prerelease: #{prerelease ? ?' + prerelease + ?' : 'false'}\n)
  elsif l.start_with? 'version: '
    %(version: '#{major_minor_version}'\n)
  else
    l
  end
end

File.write changelog_file, changelog_contents.join, mode: 'w:UTF-8'
File.write antora_file, antora_contents.join, mode: 'w:UTF-8'
