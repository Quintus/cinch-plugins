require "mkfifo"
require "cinch"
require_relative "plugins/fifo"
require_relative "plugins/http_server"
require_relative "plugins/github_commits"

cinch = Cinch::Bot.new do

  configure do |config|
    config.server     = "irc.freenode.net"
    config.port       = 6697
    config.ssl.use    = true
    config.ssl.verify = false

    config.channels = ["#cinch-bots"]
    config.nick     = "mega-cinch"
    config.user     = "cinch"

    config.plugins.options[Cinch::Fifo] = {
      :path => "/tmp/myfifo"
    }

    config.plugins.options[Cinch::HttpServer] = {
      :host => "localhost",
      :port => 1234
    }

    config.plugins.plugins = [Cinch::Fifo, Cinch::HttpServer, Cinch::GithubCommits]
  end

  trap "SIGINT" do
    bot.log("Cought SIGINT, quitting...", :info)
    bot.quit
  end

  trap "SIGTERM" do
    bot.log("Cought SIGTERM, quitting...", :info)
    bot.quit
  end

end

cinch.start
