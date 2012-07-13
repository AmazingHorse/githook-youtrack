#!/usr/bin/env ruby

require 'net/http'
require 'nokogiri'

server_url = 'youtrack.server.com'

text = '''
This is a test comment that should look for youtrack #yt-123
issues. It should find all of them and check them against
the #xx-321 youtrack #ab-789 server #cd-581
'''

puts "issues from text"
puts text
puts

issue_regex = /( |^)#(\w+-\d+)/

issues = text.scan(issue_regex) { |m, issue|
  http = Net::HTTP.new(server_url)

  exists_url = "/rest/issue/#{issue}"
  request = Net::HTTP::Get.new(exists_url)
  response = http.request(request)

  puts "Issue not found: #{issue}" if response.code == '404'
  puts "Issue found: #{issue}" unless response.code != '200'
}
