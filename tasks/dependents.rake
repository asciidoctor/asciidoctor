# frozen_string_literal: true
namespace :build do
  desc 'Trigger builds for all dependent projects on Travis CI and Github Actions'
  task :dependents do
    if ENV['TRAVIS'].to_s == 'true'
      next unless ENV['TRAVIS_PULL_REQUEST'].to_s == 'false' &&
        ENV['TRAVIS_TAG'].to_s.empty? &&
        (ENV['TRAVIS_JOB_NUMBER'].to_s.end_with? '.1')
    end

    if (commit_hash = ENV['TRAVIS_COMMIT'])
      commit_memo = %( (#{commit_hash.slice 0, 8})\n\nhttps://github.com/#{ENV['TRAVIS_REPO_SLUG'] || 'asciidoctor/asciidoctor'}/commit/#{commit_hash})
    end

    # NOTE The TRAVIS_TOKEN env var must be defined in the Travis interface.
    # Retrieve this token using the `travis token` command.
    # The GitHub user corresponding to the Travis user must have write access to the repository.
    # After granting permission, sign into Travis and resync the repositories.
    travis_token = ENV['TRAVIS_TOKEN']

    # NOTE The GITHUB_TOKEN env var must be defined in the Travis interface.
    # Retrieve this token using the settings of the account/org -> Developer Settings -> Personal Access Tokens
    # and generate a new "Personal Access Token" with the "repo" scope
    github_token = ENV['GITHUB_TOKEN']

    require 'json'
    require 'net/http'
    require 'open-uri'
    require 'yaml'

    %w(
      asciidoctor/asciidoctor-diagram
      asciidoctor/asciidoctor-reveal.js
    ).each do |project|
      org, name, branch = parse_project project
      project = [org, name, branch] * '/'
      header = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Travis-API-Version' => '3',
        'Authorization' => %(token #{travis_token})
      }
      config = YAML.load OpenURI.open_uri(%(https://raw.githubusercontent.com/#{project}/.travis-upstream-only.yml)) {|fd| fd.read } rescue {}
      payload = {
        'request' => {
          'branch' => branch,
          'message' => %(Build triggered by Asciidoctor#{commit_memo}),
          'config' => config
        }
      }.to_json
      trigger_build project, header, payload, 'api.travis-ci.org', %(/repo/#{org}%2F#{name}/requests)
    end if travis_token

    %w(
      asciidoctor/asciidoctor.js
      asciidoctor/asciidoctorj
    ).each do |project|
      org, name, branch = parse_project project
      project = [org, name, branch] * '/'
      header = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/vnd.github.everest-preview+json',
        'Authorization' => %(token #{github_token})
      }
      payload = {
        'event_type' => 'test_upstream',
        'client_payload' => {
          'branch' => branch,
          'message' => %(Build triggered by Asciidoctor#{commit_memo})
        }
      }.to_json
      trigger_build project, header, payload, 'api.github.com', %(/repos/#{org}/#{name}/dispatches)
    end if github_token
  end

  def trigger_build project, header, payload, host, path
    (http = Net::HTTP.new host, 443).use_ssl = true
    request = Net::HTTP::Post.new path, header
    request.body = payload
    response = http.request request
    if /^20\d$/.match? response.code
      puts %(Successfully triggered build on #{project} repository)
    else
      warn %(Unable to trigger build on #{project} repository: #{response.code} - #{response.message})
    end
  end

  def parse_project project
    org, name, branch = project.split '/', 3
    branch ||= 'master'
    return org, name, branch
  end
end
