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

require "date"
require "json"

class Cinch::GithubCommits
  include Cinch::Plugin
  extend Cinch::HttpServer::Verbs

  post "/github_commit" do
    halt 400 unless params[:payload]

    info = JSON.parse(params[:payload])
    repo = info["repository"]["name"]
    date = DateTime.parse(info["commits"].last["timestamp"]).strftime('%Y-%m-%d %H:%M')
    author = info["commits"].last["author"]["name"]
    oid = info["commits"].last["id"][0..7]
    desc = info["commits"].last["message"]

    if info["commits"].count == 1
      bot.channels.each{|c| c.send("[#{repo}] One new commit")}
      bot.channels.each{|c| c.send("[#{repo}] On #{date}, #{author} commited #{oid}: #{desc.lines.first.chomp}")}
    else
      bot.channels.each{|c| c.send("[#{repo}] #{info["commits"].count} new commits")}
      bot.channels.each{|c| c.send("[#{repo}] On #{date}, #{author} commited the latest one, #{oid}: #{desc.lines.first.chomp}")}
    end

    204
  end


end
