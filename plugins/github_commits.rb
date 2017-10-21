# -*- coding: utf-8 -*-
#
# = Cinch GithubCommits plugin
# This plugin uses the HttpServer plugin for Cinch in order
# to implement a simple service that understands GitHub’s
# post-commit webhook (see https://developer.github.com/v3/activity/events/types/#pushevent).
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
# Copyright © 2012, 2017 Marvin Gülker
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

require "date"
require "json"

class Cinch::GithubCommits
  include Cinch::Plugin
  extend Cinch::HttpServer::Verbs

  Commit = Struct.new(:id, :message, :author, :date)

  post "/github_commit" do
    info   = JSON.parse(request.body.read)

    hsh    = info["commits"].sort{|a, b| DateTime.parse(a["timestamp"]) <=> DateTime.parse(b["timestamp"])}.last
    commit = Commit.new(hsh["id"],
                        hsh["message"],
                        hsh["author"]["name"],
                        DateTime.parse(hsh["timestamp"]))
    repo   = info["repository"]["name"]
    branch = info["ref"].split("/").last

    if info["commits"].count == 1
      bot.channels.each{|c| c.send("[#{repo}] One new commit")}
      bot.channels.each{|c| c.send("[#{repo}] On #{commit.date.strftime('%Y-%m-%d %H:%M %:z')}, #{commit.author} commited #{commit.id[0..6]} on #{branch}: #{commit.message.lines.first.chomp}")}
    else
      bot.channels.each{|c| c.send("[#{repo}] #{info["commits"].count} new commits")}
      bot.channels.each{|c| c.send("[#{repo}] On #{commit.date.strftime('%Y-%m-%d %H:%M %:z')}, #{commit.author} commited the latest one, #{commit.id[0..6]} on #{branch}: #{commit.message.lines.first.chomp}")}
    end

    204
  end

end
