#!/usr/bin/env ruby

require 'net/http'
require 'nokogiri'

server_url = ARGV.first

text = '''
This is a test comment that should look for youtrack #yt-123
issues. It should find all of them and check them against
the #xx-321 youtrack #ab-789 server #ms-581 #xyz-246
'''

puts "issues from text"
puts text
puts

issue_regex = /( |^)#(\w+-\d+)/

text.scan(issue_regex) { |m, issue|
  http = Net::HTTP.new(server_url)

  issue_url = "/rest/issue/#{issue}"
  request = Net::HTTP::Get.new(issue_url)
  response = http.request(request)

  puts "Issue not found: ##{issue}" if response.code == '404'
  puts "Issue found: ##{issue}" unless response.code != '200'

  if response.code == '200'
    xml = Nokogiri::XML(response.body)
    type = xml.xpath('//field[@name = "Type"]/value/text()').inner_text()
    approved = xml.xpath('//field[@name = "Approved For Work"]/value/text()').inner_text()
    puts "Type: #{type}"
    puts "Approved: #{approved}"
    puts "Feature unapproved for work" unless approved.to_str.downcase == "approved"
  end
}
