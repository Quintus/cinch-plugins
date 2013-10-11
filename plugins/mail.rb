# -*- coding: utf-8 -*-
#
# = Cinch mail notification plugin
# This plugin makes Cinch write you an email when your nick
# gets mentioned while you’re not in the channel.
#
# == Usage
# Issue this command in public:
#
#   cinch: mail to john@example.net
#
# You can also privately message Cinch:
#
#   /msg cinch mail to john@example.net
#
# Whenever your nick is mentioned now with you not being
# in the channel, Cinch will write a short email to you.
#
# To unregister, use:
#
#   cinch: stopmail
#
# Or:
#
#   /msg cinch stopmail
#
# == Dependencies
# Gems:
# * mail
#
# Other:
# * You need a working `sendmail' command on the machine
#   running Cinch.
#
# == Configuration
# None.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A mail notification plugin for the Cinch IRC bot.
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

require "mail"

class Cinch::Mail
  include Cinch::Plugin

  listen_to :connect, :method => :on_connect
  listen_to :channel, :method => :on_channel

  match /cinch mail to (.*)/, :method => :register,   :react_on => :channel
  match /cinch mail to (.*)/, :method => :register,   :react_on => :private, :use_prefix => false
  match /cinch stopmail/,     :method => :unregister, :react_on => :channel
  match /cinch stopmail/,     :method => :unregister, :react_on => :private, :use_prefix => false

  set :help <<-HELP
cinch mail to <email>
  Registers you for mailing mentions of your nick.
/msg cinch mail to <email>
  Registers you for mailing mentions of your nick.
cinch stopmail
   Unregisters you for mailing mentions of your nick.
/msg cinch stopmail
   Unregisters you for mailing mentions of your nick.
  HELP

  def on_connect(*)
    @registered_users = {}
  end

  def register(msg, address)
    # Prevent users to abuse cinch for spamming by requiring
    # them to be authenticated.
    unless msg.user.authed?
      msg.reply("You must authenticate against NickServ for this feature.")
      return
    end

    @registered_users[msg.user.nick] = address
  end

  def unregister(msg)
    unless msg.user.authed?
      msg.reply("You must authenticate against NickServ for this feature.")
      return
    end

    @registered_users.delete(msg.user)
  end

  def on_channel(msg)
    return if msg.message.start_with?("\u0001") # action message

    nicks = @registered_users.keys.find_all{|nick| msg.message.include?(nick)}
    nicks.each{|nick| deliver(msg, nick)}
  end

  private

  def deliver(msg, nick)
    email = Mail.new do
      from "#{bot.nick} <#{bot.nick}@#{bot.irc.network.name}>"
      to @registered_users[nick]
      subject "You have been mentioned in #{msg.channel.name}"
      body <<-EOF
Hi #{nick},

your nick has been mentioned on IRC by #{msg.user.nick} in
#{msg.channel.name}. Here’s the exact message:

#{msg.user.nick} at #{message.time.strftime('%Y-%m-%d %H:%M %:z')}:
> #{msg.message}

If you do no longer wish to receive this notifications, issue

  /msg #{bot.nick} stopmail

once you have authenticated against NickServ.

--
This is an automatically generated message.
Do not reply to it.
      EOF
    end

    email.delivery_method :sendmail

    email.deliver
  end

end
