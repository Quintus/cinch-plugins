# -*- coding: utf-8 -*-
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
      bot.channels.each{|c| c.send("[#{repo}] On #{date}, #{author} commited #{oid}: #{desc}")}
    else
      bot.channels.each{|c| c.send("[#{repo}] #{info["commits"].count} new commits")}
      bot.channels.each{|c| c.send("[#{repo}] On #{date}, #{author} commited the latest one, #{oid}: #{desc}")}
    end

    204
  end


end
