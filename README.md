Plugin collection for Cinch
===========================

This repository contains a number of probably useful plugins for the
[Cinch](https://github.com/cinchrb/cinch) IRC bot, the best IRC bot
library that ever has been written (at least in Ruby).

Usage
-----

Currently the plugins are not available via RubyGems, but this will
follow soon I guess. In the meantime, download the plugin files
directly from GitHub (or clone the Git repository), place them inside
a directory `plugins/` and require them via Ruby’s normal
`require_relative` mechanism. A minimal IRC bot utilising the Fifo
plugin may look like this:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ruby
require "cinch"
require_relative "plugins/fifo"

cinch = Cinch::Bot.new do
  configure do |config|
    config.server = "irc.freenode.net"
    config.channels = ["#cinch-bots"]
    config.nick = "fifo-cinch"
    config.plugins.plugins = [Cinch::Fifo]

    config.plugins.options[Cinch::Fifo] = {
      :path => "/tmp/myfifo",
      :mode => 0666
    }
  end

  trap "SIGINT" do
    bot.quit
  end
end

cinch.start
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

As long as this bot runs, everything any program writes to the pipe at
`/tmp/myfifo` will be echoed to the IRC channel #cinch-bots on
irc.freenode.net.

List of plugins
---------------

This repository currently provides the following plugins:

Echo
: Makes Cinch echo messages.

Fifo
: Opens a FIFO which echoes everything written to it into IRC.

GithubCommits
: Uses the HttpServer plugin to create a listener for GitHub’s
  post-commit webhook that pastes freshly pushed commits into
  IRC.

History
: Ever joined a channel in the middle of a discussion and couldn't
  follow? This plugin is for you: It enables Cinch to replay a
  limited number of messages, solely for you.

HttpServer
: Adds a HTTP server facility to cinch, using Sinatra and Thin.
  This plugin is not meant to be used standalone, but you can
  built your own request-accepting plugins on top of it.

LinkInfo
: When Cinch spots a link, he follows it and pastes the
  returned HTML’s `title` and `description` meta tags
  into the channel.

Logging
: A plugin for creating message-only logfiles you can publish
  somewhere.

PidFile
: Allows you to create a PID file for your Cinch process.

Self
: This is not a plugin, but rather a helper for writing plugins
  that make Cinch understand messages with start by Cinch’s nickname
  followed by a colon. See the Echo plugin’s code for a simple
  example using the ::recognize method provided by this helper.

Many plugins are highly configurable, so you really want to check out
each plugin’s documentation at the top of the respective plugin file.

License
-------

All Cinch plugins found in this repository are licensed under the GNU
Lesser General Public License version 3 or later, except where
otherwise noted in the respective plugin’s file. See COPYING for the
full GPL license text, COPYING.LESSER for the LGPL license text, and
each plugin file for a short per-plugin copyright statement.
