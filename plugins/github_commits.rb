require "datetime"
require "json"

class Cinch::GithubCommits
  include Cinch::Plugin
  extend Cinch::HttpServer::Verbs

  post "/github_commit" do
    halt 400 unless params[:payload]

    info = JSON.parse(params[:payload])
    repo = info["repository"]["name"]
    date = DateTime.parse(info["commits"]["last"]["timestamp"]).strftime('%Y-%m-%d %H:%M')
    author = info["commits"]["last"]["author"]["name"]

    if info["commits"].count == 1
      say "[#{repo}] One new commit"
      say "[#{repo}] On #{date}, #{author} commited #{oid}: #{desc}"
    else
      say "[#{repo}] #{info["commits"].count} new commits"
      say "[#{repo}] On #{date}, #{author} commited the latest one, #{oid}: #{desc}"
    end
    
  end

  def say(msg)
    bot.channels.each{|channel| channel.send(msg)}
  end

end
