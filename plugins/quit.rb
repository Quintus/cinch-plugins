# -*- coding: utf-8 -*-
#
# = Cinch Quit plugin
# A really simple plugin for making your Cinch bot leave the
# IRC. Just issue a +quit+ command to him and he will leave;
# optionally only ops can do this.
#
# == Dependencies
# None.
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins[Cinch::Quit] = {
#     :op => false
#   }
#
# [op]
#   If enabled, the +quit+ command can only be issued by someone
#   who has operator privileges in the channel he issues the command
#   in; additionally, if this option is enabled, the +quit+ command
#   can only be issued publicely in a channel and is ignored if
#   received via PM.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A quit-the-irc plugin for Cinch.
# Copyright © 2013 Marvin Gülker
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

class Cinch::Quit
  include Cinch::Plugin

  match /quit/

  set :help, <<-HELP
cinch quit
  Orders me to leave the IRC. Depending on the
  configuration, you may have to be op for this.
  HELP

  def execute(msg)
    if config[:op]
      if msg.channel
        unless msg.channel.opped?(msg.user)
          bot.warn("Unauthorized quit command from #{msg.user.nick} in #{msg.channel.name}")
          msg.reply("You are not authorized to command me so!", true)
          return
        end
      else
        bot.warn("Ignoring private quit request from #{msg.user.nick} due to :op configuration option")
        msg.reply("You can only demand this in public.")
        return
      end
    end

    bot.info("Received valid quit command from #{msg.user.name}")
    msg.reply("OK. Have a nice day everybody.")
    bot.quit("Quitting on command of #{msg.user.name}")
  end

end
