#!/usr/bin/env ruby

require 'mechanize'
require 'json'
require 'digest'
require 'twitter'

env = JSON.parse(File.open("env.json", "r").read()) 

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = env["twitter_consumer_key"]
  config.consumer_secret     = env["twitter_consumer_secret"]
  config.access_token        = env["twitter_access_token"]
  config.access_token_secret = env["twitter_access_token_secret"]
end


puts "Starting BlueKeepTracker Bot!"

# client.update("Don't mind me, just testing my code for when it goes opensource :)")

@agent = Mechanize.new()
# Read already saved repo's
discovered_repos = JSON.parse(File.open("data.json", "r").read()) 
repo_commits = JSON.parse(File.open("commit_data.json", "r").read()) 

puts 'Brain loaded...'

while true
	repos = JSON.parse(@agent.get("https://api.github.com/search/repositories\?q\=CVE-2019-0708\&sort\=stars\&order\=desc").body())["items"]

	repos.each do |repo|
		repo_data = {
			"name" => repo["name"],
			"owner" => repo["owner"]["login"],
			"url" => repo["html_url"]
		}


		if discovered_repos.include? repo_data
			# do nothing unless verbose
		else
			puts "New Repo Discovered!\nName: #{repo["name"]} - Owner: #{repo["owner"]["login"]} - #{repo["html_url"]}"
			client.update("New Repo Discovered!\nName: #{repo["name"]} - Owner: #{repo["owner"]["login"]} - #{repo["html_url"]}")
			discovered_repos.push(repo_data)
			File.open("data.json","w") do |f|
  				f.write(discovered_repos.to_json)
			end
		end
	end

	discovered_repos.each do |repo|
		begin
			# puts "https://api.github.com/repos/#{repo["owner"]}/#{repo["name"]}/commits"
			commit_history = @agent.get("https://api.github.com/repos/#{repo["owner"]}/#{repo["name"]}/commits?client_id=#{env["github_client_id"]}&client_secret=#{env["github_client_secret"]}").body()
		rescue Exception => e
			# puts "We hit rate limits maybe #{e.to_s}"
			commit_history = "empty"
		end

		commit_hash = Digest::MD5.hexdigest commit_history

		if !repo_commits.key?(repo["url"]) and (commit_hash != "a2e4822a98337283e39f7b60acf85ec9")
			repo_commits[repo["url"]] = commit_hash
		else
			if (repo_commits[repo["url"]] != commit_hash) and (commit_hash != "a2e4822a98337283e39f7b60acf85ec9")
				puts "#{repo["owner"]}/#{repo["name"]} has changed!"
				client.update("#{repo["owner"]}/#{repo["name"]} has changed!\n\n#{JSON.parse(commit_history)[0]["html_url"]}")
				begin
					puts JSON.parse(commit_history)[0]["html_url"]
				rescue
					#
				end
				repo_commits[repo["url"]] = commit_hash
			end
		end

		File.open("commit_data.json","w") do |f|
  			f.write(repo_commits.to_json)
		end
		sleep 2
	end

	puts "Sleeping 60 seconds..."
	sleep 60
end