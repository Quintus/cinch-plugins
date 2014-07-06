# -*- coding: utf-8 -*-
#
# This is a sample robot using some of the plugins in this
# repository, mainly intended for testing purposes. You may
# find it useful as a working usage example of some of the
# plugins.

# Require Cinch
require "cinch"
require "fileutils"

# Require our plugins
require_relative "plugins/echo"
require_relative "plugins/logplus"
require_relative "plugins/link_info"
require_relative "plugins/tickets"

FileUtils.mkdir_p("/tmp/logs/plainlogs")
FileUtils.mkdir_p("/tmp/logs/htmllogs")

# Define the robot
cinch = Cinch::Bot.new do

  configure do |config|

    ########################################
    # Cinch options

    # Server stuff
    config.server     = "localhost"
    config.port       = 6667
    config.ssl.use    = false
    config.ssl.verify = false

    # User stuff
    config.channels = ["#test"]
    config.nick     = "mega-cinch"
    config.user     = "cinch"

    ########################################
    # Plugin options

    # Default prefix is the bot’s name
    config.plugins.prefix = lambda{|msg| Regexp.compile("^#{Regexp.escape(msg.bot.nick)}:?\s*")}

    config.plugins.options[Cinch::LogPlus] = {
      :plainlogdir => "/tmp/logs/plainlogs",
      :htmllogdir  => "/tmp/logs/htmllogs"
    }

    config.plugins.options[Cinch::Tickets] = {
      :url => "http://example.org/tickets/%d"
    }

    #
    ## List of plugins to load
    config.plugins.plugins = [Cinch::Echo, Cinch::LogPlus, Cinch::LinkInfo, Cinch::Tickets]
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
  loggers.first.level = :debug

end

cinch.start
