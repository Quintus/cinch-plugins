# -*- coding: utf-8 -*-
#
# = Cinch Memo plugin
# This plugin enables Cinch to remember short memo messages for
# someone who currently isn’t in the channel. If the nick in
# question joins the channel, Cinch will automatically post
# the memoised message into the channel (prefixed with the
# nick). Example usage:
#
#   <me> cinch: memo for mom: I'm back soon!
#   <me leaves>
#   <mom joins>
#   <cinch> mom: Memo from me: I'm back soon!
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins[Cinch::Memo] = {
#     :max_lifetime => 7
#   }
#
# [max_lifetime (7)]
#   Cinch doesn’t remember memos for infinity, because this
#   may badly impact your sever’s memory usage, depending on
#   how aggressive users are when storing memos into Cinch.
#   Therefore, each memo is assigned a lifetime value, starting
#   at the value specified via this configuration option. Every
#   half an hour, Cinch decreases each memo’s lifetime by one,
#   and if any memo’s lifetime reaches the value 0 (zero), Cinch
#   silently discards the memo (a message will be printed to the
#   log on debug level, though). If the target nick joins while
#   the memo is still valid, it will also be deleted from the
#   list of memos after having been delivered, of course.
#
# == Author
# Marvin Gülker
#
# == License
# A memo message plugin for Cinch.
# Copyright © 2012 Marvin Gülker
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

require_relative "self"

class Cinch::Memo
  include Cinch::Plugin
  extend Cinch::Self

  # Struct encapsulating the information of a single memo.
  # Note that the target nick isn’t stored here, but rather
  # is used as the key in a hash to access memos.
  Memo = Struct.new(:lifetime, :message, :sender, :channel)

  # Interval to check the remaining lifetime of the memos in.
  LIFETIME_CHECK_INTERVAL = 60 * 30 # 0.5h

  listen_to :connect,                :method => :setup
  listen_to :join,                   :method => :check_on_join
  timer LIFETIME_CHECK_INTERVAL,     :method => :check_lifetimes
  recognize /memo for (.*?): (.*)/i, :method => :memoize

  set :help, <<-HELP
cinch: memo for <nick>: <message>
  Makes me remember a notice for <nick>. When <nick> joins the
  channel, I’ll post <message> indicating you told me to do so.
  If <nick> doesn’t join for a long time, I’ll discard the memo.
  HELP

  # Initialize the plugin
  def setup(*)
    @memos = Hash.new{|hsh, k| hsh[k] = []}
    @max_lifetime = config[:max_lifetime] || 7

    bot.info("Maximum memo lifetime set to #{@max_lifetime}.")
  end

  # Whenever anyone joins, check if we have memos.
  def check_on_join(msg)
    if msg.user.nick == bot.nick
      # If we just entered a channel, check if we have memos for any user
      # in there.
      msg.channel.users.keys.each do |user|
        process_memos_for(user)
      end
    else
      # Otherwise, check if we have memos for the particular user who
      # joined.
      process_memos_for(msg.user)
    end
  end

  # Decrease memo lifetimes.
  def check_lifetimes
    @memos.each_pair do |nick, memos|
      # Decrease all this nick’s memos’ lifetimes by one.
      # If a memo reaches a lifetime of zero, delete it
      # so we don’t get overloaded.
      memos.reject! do |memo|
        memo.lifetime -= 1

        if memo.lifetime <= 0
          bot.debug("Memo from #{memo.sender.nick} to #{nick} dropped: Lifetime expired")
          true
        else
          false
        end
      end
    end
  end

  # Memoize a memo. Rejects memos for the bot itself.
  def memoize(msg, nick, memo)
    # Cannot write memos to the bot
    if nick == bot.nick
      msg.reply("#{msg.user.nick}: Nice try. Forget it.")
      return
    end

    bot.debug("Remembering a memo from #{msg.user.nick} for #{nick}")
    @memos[nick] << Memo.new(@max_lifetime, memo, msg.user, msg.channel)

    msg.reply("#{msg.user.nick}: OK, I'll notify #{nick} when (s)he enters the channel.")
  end

  private

  # Checks if any pending memos for +user+ exist, and if so
  # delivers them to him, deleting them from the list of
  # saved memos.
  def process_memos_for(user)
    memos = @memos[user.nick]

    while memo = memos.pop
      bot.debug("Delivering a memo from #{memo.sender.nick} to #{user.nick}")
      memo.channel.send("#{user.nick}: Memo from #{memo.sender.nick}: #{memo.message}")
    end
  end

end
