#!/usr/bin/env ruby

require 'net/http'
require 'nokogiri'

## FILL THESE IN

# Youtrack server URL/port
$server_url = "10.86.86.132"
$port = 8080

# Youtrack credentials (root password plaintext, I know...)
$username = "root"
$password = "root"

## END

if $server_url.nil?
  puts '[Error] $server_url not set, set this to your YouTrack url'
  exit 1
end

# import stash env variables
#variables = %w{STASH_USER_NAME STASH_REPO_NAME}
#missing = variables.find_all { |v| ENV[v] == nil }
#unless missing.empty?
#    raise "[Error] The following environment variables are missing and are needed to run this script: #{missing.join(', ')}."
#end

$from_ref = "8f36678"#ARGV.first
$to_ref = "c2b6a07"#ARGV.second

if $from_ref.to_s == '' || $to_ref.to_s == ''
	puts "[Error] Git references not specified. Usage: yim [ref1] [ref2]"
end
	
#get list of commits since last push
$git_log = `git log --oneline #{$from_ref}~1..#{$to_ref}`

# if it's empty, quit and let git handle it
if $git_log.to_s == ''
	exit 0
end

# Split the string on newlines (Watch out for windows!)
$commit_list = $git_log.split(/\r?\n/)

# for each message, add the SHA and message to seperate identically indexed arrays
$hashes = Array.new
$messages = Array.new
$hashes_regex = /\s.*/
$messages_regex = /^\w*\s*/

$commit_list.each do |commit| 
	$hashes.push commit.sub $hashes_regex, ''
	$messages.push commit.sub $messages_regex, ''
end	

# looks for #<proj>-<issue#> strings
$issue_regex = /( |^)#(\w+-\d+)/

# looks for #<proj>-<issue#> strings, with trailing spaces, colons, or hyphens
$remove_issue_regex = /( |^)#(\w+-\d+):? ? -? ?/

$invalid_commit = false

def invalid_commit
  $invalid_commit = true
end

def youtrack_login username, password
	http = Net::HTTP.new($server_url, $port)
	# First, login to youtrack given above credentials
	login_url = "/youtrack/rest/user/login"
	puts "Logging into Youtrack as root..."
	request = Net::HTTP::Post.new(login_url)
	request.body = "login=#{username}&password=#{password}"
	request["Connection"] = "keep-alive"
	response = http.request(request)
	puts "Success!"
	# Save cookies for subsequent API requests
	cookies = response.response['set-cookie']
	return cookies
end

def check_issue_exists(issue, cookies)
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

def scan_for_issues(user, cookies)
  $commit_message.scan($issue_regex) { |m, issue|
	response = check_issue(issue, cookies)
    if response.to_s == ''
		puts "[Policy Violation] - Issue not found: ##{issue}"
		invalid_commit
		return
	end
	# Remove issue# from commit message and parse
	message = $commit_message.gsub($remove_issue_regex, '')
	add_comment_to_issue(issue, message, user, cookies)
  }
end

def validate_commit user, cookies
  if !$issue_regex.match($commit_message)
    invalid_commit
    puts '[Policy Violation] - No YouTrack issues found in commit message'
    return
  end
  check_issue_exists user, cookies
end

# An example of how to parse the YouTrack response and validate
# against a custom field
def add_comment_to_issue(issue, message, user, cookies)
	http = Net::HTTP.new($server_url, $port)
	# First, login to youtrack given above credentials
	comment_url = "/youtrack/rest/issue/#{issue}/execute"
	request = Net::HTTP::Post.new(comment_url)
	request.body = "comment=#{message}&runAs=#{user}"
	request['Cookie'] = cookies
    response = http.request(request)
end

puts 'Checking YouTrack issues...'
cookies = youtrack_login $username, $password
#validate_commit user, cookies

if $invalid_commit
  puts "[Error] - Commit rejected, please fix commit message and try again"
  puts
  puts $commit_message
  exit 1
end
