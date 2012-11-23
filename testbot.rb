# -*- coding: utf-8 -*-
#
# This is a sample robot using some of the plugins in this
# repository, mainly intended for testing purposes. You may
# find it useful as a working usage example of some of the
# plugins.

# Require Cinch
require "cinch"

# Require our plugins
require_relative "plugins/fifo"
require_relative "plugins/http_server"
require_relative "plugins/github_commits"
require_relative "plugins/link_info"
require_relative "plugins/echo"

# Define the robot
cinch = Cinch::Bot.new do

  configure do |config|

    # Cinch options
    config.server     = "irc.freenode.net"
    config.port       = 6697
    config.ssl.use    = true
    config.ssl.verify = false

    config.channels = ["#cinch-bots"]
    config.nick     = "mega-cinch"
    config.user     = "cinch"

    # Plugin options
    config.plugins.options[Cinch::Fifo] = {
      :path => "/tmp/myfifo"
    }

    config.plugins.options[Cinch::HttpServer] = {
      :host => "localhost",
      :port => 1234,
      #:logfile => "/tmp/cinch-http.log"
    }

    # List of plugins to load
    config.plugins.plugins = [Cinch::Fifo, Cinch::HttpServer, Cinch::GithubCommits, Cinch::LinkInfo, Cinch::Echo]
  end

  trap "SIGINT" do
    bot.log("Cought SIGINT, quitting...", :info)
    bot.quit
  end

  trap "SIGTERM" do
    bot.log("Cought SIGTERM, quitting...", :info)
    bot.quit
  end

  # Set up a logger so we have something more persistant
  # than $stderr. Note this sadly cannot be done in a
  # plugin, because plugins are loaded after a good number
  # of log messages have already been created.
  file = open("/tmp/cinch.log", "a")
  file.sync = true
  loggers.push(Cinch::Logger::FormattedLogger.new(file))

end

cinch.start
