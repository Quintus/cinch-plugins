# -*- coding: utf-8 -*-
#
# = Cinch GithubCommits plugin
# This plugin uses the HttpServer plugin for Cinch in order
# to implement a simple service that understands GitHub’s
# post-commit webhook (see https://help.github.com/articles/post-receive-hooks).
# When a POST request arrives, it will be parsed and a summary
# of the push results will be echoed to all channels Cinch
# currently has joined.
#
# == Dependencies
# * The HttpServer plugin for Cinch
#
# == Configuration
# Currently none.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A Cinch plugin listening for GitHub’s post-receive hooks.
# Copyright © 2012 Marvin Gülker
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "json"

class Cinch::GitHub
	include Cinch::Plugin
	extend Cinch::HttpServer::Verbs
	
	post "/github_commit" do
		halt 400 unless params[:payload]
		
		request.body.rewind
		payload_body = request.body.read
		
		type = env['HTTP_X_GITHUB_EVENT']
		usig = env['HTTP_X_HUB_SIGNATURE']
		
		halt 403, "Signature required, see https://developer.github.com/webhooks/securing/#setting-your-secret-token" unless usig
		signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['SECRET_TOKEN'], payload_body)
		halt 403, "Signatures didn't match, use https://developer.github.com/webhooks/securing/#setting-your-secret-token for help" unless Rack::Utils.secure_compare(signature, usig)
		
		info = JSON.parse(params[:payload])
		Cinch::GitHub.responses(bot, type, info).each do |rsp|
			bot.channels.each{|c| c.send(rsp)}
		end
		
		204
	end
	
	def self.fmid(str)
		return str[0..7]
	end
	
	def self.trnc(str, truncate_at, omission = '...')
		res = str
		omitted = false
		append = omission
		lines = res.split("\r\n")
		
		if lines.length > 1
			omitted = true
			append = " [#{omission}]"
			res = lines.first
		end
		
		if res.length > truncate_at
			omitted = true
			append = omission
			stop = truncate_at - omission.length
			res = "#{res[0...stop]}"
		end
		
		return res unless omitted
		return "#{res}#{append}"
	end
	
	def self.responses(bot, type, info)
		sndr = info.fetch('sender',{}).fetch('login',nil)
		repo_owner = info.fetch('repository',{}).fetch('owner',{}).fetch('login',nil)
		repo_name = info.fetch('repository',{}).fetch('name',nil)
		orgn = info.fetch('organization',{}).fetch('login',nil)
		
		sndr &&= bot.Format(:blue, sndr)
		repo_name &&= bot.Format(:bold, repo_name)
		orgn &&= bot.Format(:green, orgn)
		
		if repo_owner and repo_name
			repo = bot.Format(:green, repo_owner + '/' + repo_name)
		end
		
		return case type
			when 'commit_comment'
				link = bot.Format(:underline, bot.Format(:blue, info['comment']['html_url']))
				user = bot.Format(:blue, info['comment']['user']['login'])
				cmid = bot.Format(:orange, self.fmid(info['comment']['commit_id']))
				body = self.trnc(info['comment']['body'], 60)
				["[#{repo}] #{user} commented on commit #{cmid}: #{body} - #{link}"]
			when 'create'
				reftype = bot.Format(:bold, info['ref_type'])
				ref = bot.Format(:orange, info['ref'])
				["[#{repo}] #{sndr} created #{reftype} #{ref}"]
			when 'delete'
				reftype = bot.Format(:bold, info['ref_type'])
				ref = bot.Format(:orange, info['ref'])
				["[#{repo}] #{sndr} deleted #{reftype} #{ref}"]
			when 'deployment'
				sha = bot.Format(:orange, self.fmid(info['sha']))
				deplenv = bot.Format(:bold, info['environment'])
				desc = info['description'] ? self.trnc(': ' + info['description'], 60) : ''
				["[#{repo}] #{sndr} deployed to #{deplenv} at #{sha}#{desc}"]
			when 'deployment_status'
				cstate = case info['state']
					when 'pending'; bot.Format(:grey, 'pending')
					when 'success'; bot.Format(:green, 'succeeded')
					when 'failure'; bot.Format(:red, 'failed')
					when 'error'; bot.Format(:orange, 'returned an error')
					else; 'returned an unknown status'
				end
				sha = bot.Format(:orange, self.fmid(info['deployment']['sha']))
				deplenv = bot.Format(:bold, info['deployment']['environment'])
				desc = info['description'] ? self.trnc(': ' + info['description'], 60) : ''
				["[#{repo}] Deployment by #{sndr} to #{deplenv} at #{sha} #{cstate}#{desc}"]
			when 'fork'
				fork_owner = info['forkee']['owner']['login']
				fork_name = info['forkee']['name']
				fork_name &&= bot.Format(:bold, fork_name)
				fork = bot.Format(:orange, fork_owner + '/' + fork_name)
				["[#{repo}] #{sndr} created fork #{fork}"]
			when 'gollum'
				res = []
				info['pages'].each do |page|
					summary = page['summary'] ? self.trnc(': ' + page['summary'], 60) : ''
					link = bot.Format(:underline, bot.Format(:blue, page['html_url']))
					pgnm = bot.Format(:bold, page['title'])
					sha = bot.Format(:orange, self.fmid(page['sha']))
					actn = page['action']
					res << "[#{repo}] #{sndr} #{actn} wiki page #{pgnm} at #{sha}#{summary} - #{link}"
				end
				res
			when 'issue_comment'
				link = bot.Format(:underline, bot.Format(:blue, info['comment']['html_url']))
				user = bot.Format(:blue, info['comment']['user']['login'])
				isid = bot.Format(:orange, '#' + info['issue']['number'].to_s)
				body = self.trnc(info['comment']['body'], 60)
				actn = info['action']
				["[#{repo}] #{user} #{actn} a comment on issue #{isid}: #{body} - #{link}"]
			when 'issues'
				link = bot.Format(:underline, bot.Format(:blue, info['issue']['html_url']))
				isid = bot.Format(:orange, '#' + info['issue']['number'].to_s)
				actn = case info['action']
					when 'assigned'; "assigned #{bot.Format(:orange, info['assignee']['login'])} to"
					when 'unassigned'; "unassigned #{bot.Format(:orange, info['assignee']['login'])} from"
					when 'labeled'; "added label #{bot.Format(:orange, info['label']['name'])} to"
					when 'unlabeled'; "removed label #{bot.Format(:orange, info['label']['name'])} from"
					when 'opened'; 'opened'
					when 'closed'; 'closed'
					when 'reopened'; 'reopened'
					else; 'modified'
				end
				["[#{repo}] #{sndr} #{actn} issue #{isid} - #{link}"]
			when 'member'
				member = bot.Format(:orange, info['member']['login'])
				actn = info['action']
				["[#{repo}] #{sndr} #{actn} collaborator #{member}"]
			when 'membership'
				actn = case info['action']
					when 'added'; "added #{bot.Format(:orange, info['member']['login'])} to"
					when 'removed'; "removed #{bot.Format(:orange, info['member']['login'])} from"
					else; 'modified'
				end
				member = bot.Format(:orange, info['member']['login'])
				team = bot.Format(:orange, info['team']['name'])
				["[#{orgn}] #{sndr} #{actn} team #{team}"]
			when 'page_build'
				sha = bot.Format(:orange, self.fmid(info['build']['commit']))
				pshr = bot.Format(:blue, info['build']['pusher']['login'])
				["[#{repo}] Building GitHub Pages site after push by #{sndr} at #{sha}"]
			when 'ping'
				hook = bot.Format(:orange, info['hook_id'].to_s)
				["#{sndr} has pinged hook #{hook}: #{info['zen']}"]
			when 'public'
				link = bot.Format(:underline, bot.Format(:blue, info['repository']['html_url']))
				["[#{repo}] #{sndr} has published the repository - #{link}"]
			when 'pull_request'
				link = bot.Format(:underline, bot.Format(:blue, info['pull_request']['html_url']))
				isid = bot.Format(:orange, '#' + info['pull_request']['number'].to_s)
				actn = case info['action']
					when 'assigned'; "assigned #{bot.Format(:orange, info['assignee']['login'])} to"
					when 'unassigned'; "unassigned #{bot.Format(:orange, info['assignee']['login'])} from"
					when 'labeled'; "added label #{bot.Format(:orange, info['label']['name'])} to"
					when 'unlabeled'; "removed label #{bot.Format(:orange, info['label']['name'])} from"
					when 'opened'; 'opened'
					when 'closed'; 'closed'
					when 'reopened'; 'reopened'
					when 'synchronize'; 'synchronized'
					else; 'modified'
				end
				["[#{repo}] #{sndr} #{actn} pull request #{isid} - #{link}"]
			when 'pull_request_review_comment'
				link = bot.Format(:underline, bot.Format(:blue, info['comment']['html_url']))
				user = bot.Format(:blue, info['comment']['user']['login'])
				prid = bot.Format(:orange, '#' + info['pull_request']['number'].to_s)
				body = self.trnc(info['comment']['body'], 60)
				actn = info['action']
				["[#{repo}] #{user} #{actn} a comment on pull request #{prid}: #{body} - #{link}"]
			when 'push'
				repo_owner = info['repository']['owner']['name']
				repo_name = repo_name &&= bot.Format(:bold, info['repository']['name'])
				repo = bot.Format(:green, repo_owner + '/' + repo_name)
				link = bot.Format(:underline, bot.Format(:blue, info['head_commit']['url']))
				ref = bot.Format(:orange, info['ref'].split('/').last)
				pshr = bot.Format(:blue, info['pusher']['name'])
				count = info['commits'].count
				size = bot.Format(:bold, count.to_s)
				snoun = (count == 1 ? 'commit' : 'commits')
				res = ["[#{repo}] #{pshr} pushed #{size} new #{snoun} to #{ref} - #{link}"]
				info['commits'].each do |commit|
					desc = commit['message'] ? self.trnc(': ' + commit['message'], 60) : ''
					author = bot.Format(:blue, commit['author']['username'])
					sha = bot.Format(:orange, self.fmid(commit['id']))
					res << "[#{repo}] #{sha} by #{author}#{desc}"
				end
				res
			when 'release'
				actn = info['action']
				release = bot.Format(:orange, info['release']['tag_name'])
				author = bot.Format(:blue, info['release']['author']['login'])
				link = bot.Format(:underline, bot.Format(:blue, info['release']['html_url']))
				["[#{repo}] #{author} #{actn} release #{release} - #{link}"]
			when 'repository'
				actn = info['action']
				repo = bot.Format(:green, repo_name)
				["[#{orgn}] #{sndr} #{actn} repository #{repo}"]
			when 'status'
				cstate = case info['state']
					when 'pending'; bot.Format(:grey, 'pending')
					when 'success'; bot.Format(:green, 'succeeded')
					when 'failure'; bot.Format(:red, 'failed')
					when 'error'; bot.Format(:orange, 'returned an error')
					else; 'returned an unknown status'
				end
				sha = bot.Format(:orange, self.fmid(info['sha']))
				desc = info['description'] ? self.trnc(': ' + info['description'], 60) : ''
				cmtr = bot.Format(:blue, info['commit']['commit']['committer']['name'])
				["[#{repo}] Commit by #{cmtr} at #{sha} #{cstate}#{desc}"]
			when 'team_add'
				repo = bot.Format(:green, repo_name)
				team = bot.Format(:orange, info['team']['name'])
				["[#{orgn}] #{sndr} added repository #{repo} to team #{team}"]
			when 'watch'
				["[#{repo}] #{sndr} starred the repository"]
			else
				return [type ? "Received unknown event \"#{type}\"" : "No event type specified"]
		end
	end
end
