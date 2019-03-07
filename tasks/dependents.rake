# frozen_string_literal: true
namespace :build do
  desc 'Trigger builds for all dependent projects on Travis CI'
  task :dependents do
    if ENV['TRAVIS'].to_s == 'true'
      next unless ENV['TRAVIS_PULL_REQUEST'].to_s == 'false' &&
          ENV['TRAVIS_TAG'].to_s.empty? &&
          (ENV['TRAVIS_JOB_NUMBER'].to_s.end_with? '.1')
    end
    # NOTE The TRAVIS_TOKEN env var must be defined in Travis interface.
    # Retrieve this token using the `travis token` command.
    # The GitHub user corresponding to the Travis user must have write access to the repository.
    # After granting permission, sign into Travis and resync the repositories.
    next unless (token = ENV['TRAVIS_TOKEN'])
    require 'json'
    require 'net/http'
    require 'open-uri'
    require 'yaml'
    %w(
      asciidoctor/asciidoctor.js
      asciidoctor/asciidoctorj
      asciidoctor/asciidoctor-diagram
      asciidoctor/asciidoctor-reveal.js
    ).each do |project|
      org, name, branch = project.split '/', 3
      branch ||= 'master'
      project = [org, name, branch] * '/'
      header = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Travis-API-Version' => '3',
        'Authorization' => %(token #{token})
      }
      if (commit_hash = ENV['TRAVIS_COMMIT'])
        commit_memo = %( (#{commit_hash.slice 0, 8})\n\nhttps://github.com/#{ENV['TRAVIS_REPO_SLUG'] || 'asciidoctor/asciidoctor'}/commit/#{commit_hash})
      end
      config = YAML.load open(%(https://raw.githubusercontent.com/#{project}/.travis-upstream-only.yml)) {|fd| fd.read } rescue {}
      payload = {
        'request' => {
          'branch' => branch,
          'message' => %(Build triggered by Asciidoctor#{commit_memo}),
          'config' => config
        }
      }.to_json
      (http = Net::HTTP.new 'api.travis-ci.org', 443).use_ssl = true
      request = Net::HTTP::Post.new %(/repo/#{org}%2F#{name}/requests), header
      request.body = payload
      response = http.request request
      if response.code == '202'
        puts %(Successfully triggered build on #{project} repository)
      else
        warn %(Unable to trigger build on #{project} repository: #{response.code} - #{response.message})
      end
    end
  end
end
