Plugin collection for Cinch
===========================

This repository contains a number of probably useful plugins for the
(Cinch)[https://github.com/cinchrb/cinch] IRC bot, the best IRC bot
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

== License

All Cinch plugins found in this repository are licensed under the GNU
General Public License version 3 or later. See COPYING for the full
license text and each plugin file for a short per-plugin copyright
statement.
