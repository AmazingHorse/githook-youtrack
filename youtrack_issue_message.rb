#!/usr/bin/env ruby

#
# Copy this locally to your git repo as .git/hooks/commit-msg
#

require 'net/http'
require 'nokogiri'

$issue_regex = /( |^)#(\w+-\d+)/
$server_url = nil
$message_file = ARGV.first
$commit_message = File.read($message_file)
$invalid_commit = false

def invalid_commit
  $invalid_commit = true
end

def check_issue(issue)
    http = Net::HTTP.new($server_url)
    issue_url = "/rest/issue/#{issue}"
    request = Net::HTTP::Get.new(issue_url)
    response = http.request(request)

    if response.code == '404'
      puts "[Policy Violation] - Issue not found: ##{issue}"
      invalid_commit
    end

    validate_issue_approved(response.body, issue) if response.code == '200'
end

def check_issue_exists
  $commit_message.scan($issue_regex) { |m, issue|
    check_issue issue
  }
end

def validate_commit
  if !$issue_regex.match($commit_message)
    invalid_commit
    puts '[Policy Violation] - No YouTrack issues found in commit message'
    return
  end

  check_issue_exists
end

# An example of how to parse the YouTrack response and validate
# against a custom field
def validate_issue_approved(youtrack_response, issue)
  xml = Nokogiri::XML(youtrack_response)
  type = xml.xpath('//field[@name = "Type"]/value/text()').inner_text()
  approved = xml.xpath('//field[@name = "Approved For Work"]/value/text()').inner_text()
  task_of = xml.xpath('//field[@name = "links"]/value[@role = "subtask of"]/text()').inner_text()

  feature = type.downcase == 'feature'
  approved_for_work = feature && approved.downcase == 'approved'

  if type.downcase == 'task'
    puts "Validating #{issue}'s parent #{task_of}"
    check_issue task_of
  end

  if feature && !approved_for_work
    puts "[Policy Violation] - ##{issue} not approved for work"
    invalid_commit
  end
end

if $server_url.nil?
  puts '[Error] - $server_url not set, set this to your YouTrack url'
  exit 1
end

puts 'Checking YouTrack issues...'
validate_commit

if $invalid_commit
  puts "[Error] - Commit rejected, please fix commit message and try again"
  puts
  puts $commit_message
  exit 1
end
