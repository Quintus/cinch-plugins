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
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins[Cinch::Memo] = {
#     :sender_address => "Cinch <cinch@example.org>",
#     :nojoined => false
#   }
#
# [sender_address (guessed)]
#   The address that will show up as the sender address for
#   the mails sent. If ommitted, an address will be gussed
#   by looking at the bot’s nick, the IRC network name and
#   the configured server for Cinch. You should better set
#   this.
# [nojoined (false)]
#   Usually, Cinch doesn’t care whether you have joined the
#   channel or not when you are mentioned. You will get the
#   notification email in either case. If you want to suppress
#   this behaviour, set this option to +true+ and you will
#   only receive notifactions of mentioned when you are
#   NOT in the channel.
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

  match /mail to (.*)/, :method => :register,   :react_on => :channel
  match /mail to (.*)/, :method => :register,   :react_on => :private, :use_prefix => false
  match /stopmail/,     :method => :unregister, :react_on => :channel
  match /stopmail/,     :method => :unregister, :react_on => :private, :use_prefix => false

  set :help, <<-HELP
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

    bot.loggers.info("Registered nick for email notification: #{msg.user.nick}")
    msg.reply("Successfully registered #{msg.user.nick} for email notifications.")
  end

  def unregister(msg)
    unless msg.user.authed?
      msg.reply("You must authenticate against NickServ for this feature.")
      return
    end

    @registered_users.delete(msg.user)

    bot.loggers.info("Unregistered nick from email notification: #{msg.user.nick}")
    msg.reply("Successfully unregistered #{msg.user.nick} from email notifications.")
  end

  def on_channel(msg)
    return if msg.message.start_with?("\u0001") # action message

    channel_nicks = msg.channel.users.keys.map(&:nick)
    nicks = @registered_users.keys.find_all{|nick| msg.message.include?(nick) && (!config[:nojoined] || !channel_nicks.include?(nick))}
    #                                              nick is mentioned          && (we dont care about join status || nick is not joined)

    nicks.each{|nick| deliver(msg, nick)}
  end

  private

  def deliver(msg, nick)
    email = Mail.new
    email[:to]      =  @registered_users[nick]
    email[:subject] = "You have been mentioned in #{msg.channel.name}"
    email[:body]    = <<-EOF
Hi #{nick},

your nick has been mentioned on IRC by #{msg.user.nick} in
#{msg.channel.name} on #{bot.config.server} (#{bot.irc.network.name}).
Here’s the exact message:

#{msg.user.nick} at #{msg.time.strftime('%Y-%m-%d %H:%M %:z')}:
> #{msg.message}

If you do no longer wish to receive this notifications, issue

  /msg #{bot.nick} stopmail

once you have authenticated against NickServ.

--
This is an automatically generated message.
Do not reply to it.
    EOF

    if config[:sender_address]
      email[:from] = config[:sender_address]
    else
      # If no sender address is specified, try to use the network name if
      # it would be valid as an FQDN. If it isn’t, try the bot’s connection
      # partner. If that isn’t either (weird DNS or "localhost" in testing),
      # then just append ".invalid" and log a warning.
      if bot.irc.network.name.to_s.include?(".")
        email[:from] = "#{bot.nick} <#{bot.nick}@#{bot.irc.network.name}>"
      elsif bot.config.server.include?(".")
        email[:from] = "#{bot.nick} <#{bot.nick}@#{bot.config.server}>"
      else
        hostname = bot.config.server
        bot.loggers.warn("Could not find a valid email host name for the bot. Please set the :sender_address configuration directive. Appending '.invalid' for now.")

        hostname += ".invalid"
        bot.loggers.warn("Forcing hostname address: #{hostname}")
        email[:from] = "#{bot.nick} <#{bot.nick}@#{hostname}>"
      end
    end

    bot.loggers.info("Delivering notification email to #{nick} (mentioned by #{msg.user.nick} in #{msg.channel.name})")
    email.delivery_method :sendmail

    email.deliver
  end

end
