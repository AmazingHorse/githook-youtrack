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
		return ''
    end
	return response.body
end

def check_issue_exists(cookies)
  $commit_message.scan($issue_regex) { |m, issue|
	puts "#{m}"
	response = check_issue(issue, cookies)
    if response.to_s == ''
		puts "[Policy Violation] - Issue not found: ##{issue}"
		invalid_commit
	end
	add_comment_to_issue(issue, response, cookies)
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
def add_comment_to_issue(issue, response, cookies)
  xml = Nokogiri::XML(response)
  puts "#{xml}"
  type = xml.xpath('//field[@name = "Type"]/value/text()').inner_text()
  approved = xml.xpath('//field[@name = "Approved For Work"]/value/text()').inner_text()
  task_of = xml.xpath('//field[@name = "links"]/value[@role = "subtask of"]/text()').inner_text()
  feature = type.downcase == 'feature'
  approved_for_work = feature && approved.downcase == 'approved'
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
