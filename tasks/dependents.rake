# frozen_string_literal: true

def trigger_build project, header, payload, host, path
  require 'net/http'

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
  [org, name, branch]
end

namespace :build do
  desc 'Trigger builds for dependent projects'
  task :dependents do
    next unless ENV['GITHUB_ACTIONS'].to_s == 'true' && ENV['GITHUB_EVENT_NAME'].to_s != 'pull_request' && !(ENV['GITHUB_REF'].to_s.start_with? 'refs/tags/')

    if (commit_hash = ENV['GITHUB_SHA'])
      commit_memo = %( (#{commit_hash.slice 0, 8})\n\nhttps://github.com/#{ENV['GITHUB_REPOSITORY'] || 'asciidoctor/asciidoctor'}/commit/#{commit_hash})
    end

    # NOTE The GITHUB_TOKEN env var must be defined in the CI interface.
    # Retrieve this token using the settings of the account/org -> Developer Settings -> Personal Access Tokens
    # and generate a new "Personal Access Token" with the "repo" scope
    github_token = ENV['GITHUB_API_TOKEN']

    require 'json'

    %w(
      asciidoctor/asciidoctor.js
      asciidoctor/asciidoctorj/main
      asciidoctor/asciidoctor-pdf/main
      asciidoctor/asciidoctor-reveal.js
    ).each do |project|
      org, name, branch = parse_project project
      project = [org, name, branch].join '/'
      header = {
        'Content-Type' => 'application/json',
        'Accept' => 'application/vnd.github.everest-preview+json',
        'Authorization' => %(token #{github_token})
      }
      payload = {
        'event_type' => 'test_upstream',
        'client_payload' => {
          'branch' => (ENV['GITHUB_REF'].sub 'refs/heads/', ''),
          'message' => %(Build triggered by Asciidoctor#{commit_memo}),
        },
      }.to_json
      trigger_build project, header, payload, 'api.github.com', %(/repos/#{org}/#{name}/dispatches)
    end if github_token
  end
end
