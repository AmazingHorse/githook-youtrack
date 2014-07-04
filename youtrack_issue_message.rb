#!/usr/bin/env ruby

require 'net/http'

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
variables = %w{STASH_USER_NAME STASH_REPO_NAME}
missing = variables.find_all { |v| ENV[v] == nil }
unless missing.empty?
    raise "[Error] The following environment variables are missing and are needed to run this script: #{missing.join(', ')}."
end

$user = ENV[STASH_USER_NAME]
$repo = ENV[STASH_REPO_NAME]

$from_ref = ARGV.first
$to_ref = ARGV.second

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
$issues = Array.new
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

# FIXME: gracefully handle broken logins

def youtrack_login username, password, http
	# First, login to youtrack given above credentials
	login_url = "/youtrack/rest/user/login"
	puts "Logging into Youtrack as root..."
	request = Net::HTTP::Post.new(login_url)
	request.body = "login=#{username}&password=#{password}"
	request["Connection"] = "keep-alive"
	request["Content-Type"] = "application/x-www-form-urlencoded"
	response = http.request(request)
	puts "Success!"
	# Save cookies for subsequent API requests
	cookies = response['set-cookie']
	return cookies
end

def fixme_text hash
	puts "Run the following command:" 
	puts "\tgit rebase -i #{hash}"
	puts "You will be dumped into an editor with a bunch of your commits. The one you selected is first."
	puts "Replace 'pick' with 'reword', save and quit, then add the correct issue from youtrack in your commit."
end

# FIXME: Handle other HTTP codes?

def scan_for_issue message, hash, cookies, http
	if !$issue_regex.match(message)
		puts "[Policy Violation] - No YouTrack issues found in commit message. Please amend git commit #{hash}."
		fixme_text hash
		return ''
	end
	message.scan($issue_regex) do |m, issue|
		issue_url = "/youtrack/rest/issue/#{issue}"
		request = Net::HTTP::Get.new(issue_url)
		request['Cookie'] = cookies
		response = http.request(request)
		if response.code == '404'
			puts "[Policy Violation] - Issue not found: ##{issue}. Please amend git commit #{hash}."
			fixme_text hash
			return ''
		elsif response.code == '200'
			return issue  
		else
			puts "[Policy Violation] - Issue returns invalid HTTP response. Check your youtrack status."
			return ''
		end
	end
end

def validate_commits cookies, http
	$messages.zip($hashes).each do |message, hash|
		issue = scan_for_issue message, hash, cookies, http
		if issue.to_s == ''
			puts "[Error] - Commit rejected, please fix commit message and try again"
			exit 1
		end
		$issues.push issue
	end
end

# An example of how to parse the YouTrack response and validate
# against a custom field
def add_comments_to_issue message, hash, issue, user, cookies, http
	# Remove issue# from commit message and parse
	message_text = message.sub $remove_issue_regex, ''
	puts message_text
	# First, login to youtrack given above credentials
	comment_url = "/youtrack/rest/issue/#{issue}/execute"
	request = Net::HTTP::Post.new(comment_url)
	request.body = "comment=[#{$repo}.git] #{message_text}&runAs=#{user}"
	request['Cookie'] = cookies
    http.request(request)
end

http = Net::HTTP.new($server_url, $port)
cookies = youtrack_login $username, $password, http

puts 'Checking commits...'
if validate_commits cookies, http
	puts 'Adding data to youtrack issues...'
	$messages.zip($hashes, $issues).each do |message, hash, issue|
		# parsing/splitting of messages should happen here
		add_comments_to_issue message, hash, issue, $user, cookies, http
	end
end