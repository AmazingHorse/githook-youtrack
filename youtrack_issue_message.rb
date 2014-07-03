#!/usr/bin/env ruby

require 'net/http'
require 'nokogiri'

## FILL THESE IN

# Youtrack server URL/port
$server_url = "10.86.86.132"
$port = 8080

# Youtrack credentials (password plaintext, I know...)
$username = "bheughan"
$password = "N1kwil2btbm"

## END

$issue_regex = /( |^)#(\w+-\d+)/
$message_file = ARGV.first
$commit_message = File.read($message_file)
$invalid_commit = false

def invalid_commit
  $invalid_commit = true
end

def youtrack_login(username, password)
	http = Net::HTTP.new($server_url, $port)
	http.set_debug_output($stdout)
	# First, login to youtrack given above credentials
	login_url = "/youtrack/rest/user/login"
	request = Net::HTTP::Post.new(login_url)
	request.body = "login=#{username}&password=#{password}"
	request["Connection"] = "keep-alive"
	response = http.request(request)
	# Save cookies for subsequent API requests
	cookies = response.response['set-cookie']
	return cookies
end

def check_issue(issue, cookies)
    http = Net::HTTP.new($server_url, $port)
    issue_url = "/youtrack/rest/issue/#{issue}"
    request = Net::HTTP::Get.new(issue_url)
	request['Cookie'] = cookies
    response = http.request(request)

    if response.code == '404'
      puts "[Policy Violation] - Issue not found: ##{issue}"
      invalid_commit
    end
	
    validate_issue_approved(response.body, issue, cookies) if response.code == '200'
end

def check_issue_exists(cookies)
  $commit_message.scan($issue_regex) { |m, issue|
    check_issue issue, cookies
  }
end

def validate_commit cookies
  if !$issue_regex.match($commit_message)
    invalid_commit
    puts '[Policy Violation] - No YouTrack issues found in commit message'
    return
  end

  check_issue_exists cookies
end

# An example of how to parse the YouTrack response and validate
# against a custom field
def validate_issue_approved(youtrack_response, issue, cookies)
  xml = Nokogiri::XML(youtrack_response)
  type = xml.xpath('//field[@name = "Type"]/value/text()').inner_text()
  approved = xml.xpath('//field[@name = "Approved For Work"]/value/text()').inner_text()
  task_of = xml.xpath('//field[@name = "links"]/value[@role = "subtask of"]/text()').inner_text()

  feature = type.downcase == 'feature'
  approved_for_work = feature && approved.downcase == 'approved'

  if type.downcase == 'task'
    puts "Validating #{issue}'s parent #{task_of}"
    check_issue task_of, cookies
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
cookies = youtrack_login $username, $password
validate_commit cookies

if $invalid_commit
  puts "[Error] - Commit rejected, please fix commit message and try again"
  puts
  puts $commit_message
  exit 1
end
