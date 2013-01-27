# -*- coding: utf-8 -*-
#
# = Cinch Memo plugin
# This plugin enables Cinch to remember short memo messages for
# someone who currently isn’t in the channel or even online.
# Supports both public per-channel memos and private memos,
# where the latter are only delivered to people who identified
# against NickServ (Cinch currently supports this functionality
# currently officially only on FreeNode and QuakeNet).
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
# Copyright © 2012, 2013 Marvin Gülker
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

class Cinch::Memo
  include Cinch::Plugin

  # Struct encapsulating the information of a single memo.
  # Note that the target nick isn’t stored here, but rather
  # is used as the key in a hash to access memos.
  Memo = Struct.new(:lifetime, :message, :sender, :channel)

  # Interval to check the remaining lifetime of the memos in.
  LIFETIME_CHECK_INTERVAL = 60 * 30 # 0.5h

  listen_to :connect,            :method => :on_connect
  listen_to :join,               :method => :on_join
  listen_to :online,             :method => :on_online
  timer LIFETIME_CHECK_INTERVAL, :method => :check_lifetimes
  match /memo for (.*?): (.*)/i, :method => :memoize, :react_on => :channel
  match /memo for (.*?): (.*)/i, :method => :private_memoize, :react_on => :private, :use_prefix => false

  set :help, <<-HELP
cinch memo for <nick>: <message>
  Makes me remember a notice for <nick>. When <nick> joins the
  channel, I’ll post <message> indicating you told me to do so.
  If <nick> doesn’t join for a long time, I’ll discard the memo.
/msg cinch memo for <nick>: <message>
  Makes me remember a private notice for <nick>. When <nick> comes
  online and identifies against NickServ, I'll send him <message>
  privately. I discard the memo if <nick> doesn't connect for a long time.
  HELP

  # Initialize the plugin
  def on_connect(*)
    @public_memos  = Hash.new{|hsh, k| hsh[k] = []}
    @private_memos = Hash.new{|hsh, k| hsh[k] = []}
    @max_lifetime  = config[:max_lifetime] || 7
    @public_mutex  = Mutex.new
    @private_mutex = Mutex.new

    bot.loggers.debug("Maximum memo lifetime set to #{@max_lifetime}.")
  end

  # Whenever anyone joins, check if we have memos for him
  # in this particular channel.
  def on_join(msg)
    @public_mutex.synchronize do
      @public_memos[msg.user.nick].select{|memo| memo.channel.name == msg.channel.name}.each do |memo|
        bot.loggers.info("Delivering a public memo in #{memo.channel.name} from #{memo.sender.nick} to #{msg.user.nick}")
        msg.reply("Memo from #{memo.sender.nick}: #{memo.message}", true)

        @public_memos[msg.user.nick].delete(memo)
      end
    end
  end

  # When a user gets online, wait for him to identify, then
  # sent him all the private memos that have been collected.
  def on_online(msg, user)
    return unless @private_memos.keys.include?(user.nick)

    Thread.new do
      loop do
        # Wait for the user to (auto-)authenticate
        sleep 10
        next unless user.authed?

        # Deliver all the memos
        @private_mutex.synchronize do
          while memo = @private_memos[user.nick].pop # Single = intended
            bot.loggers.info("Delivering a private memo from #{memo.sender.nick} to #{user.nick}")
            user.msg("Memo from #{memo.sender.nick}: #{memo.message}")
          end
        end

        # We now don’t need to know about him anymore, so
        # don’t put unnecessary strain on the IRC server.
        user.unmonitor
        break
      end
    end
  end

  # Decrease memo lifetimes.
  def check_lifetimes
    @public_mutex.synchronize do
      @public_memos.each_pair{|target, memos| memos.delete_if{|memo| (memo.lifetime -= 1) <= 0}}
      @public_memos.delete_if{|target, memos| memos.empty?}
    end

    @private_mutex.synchronize do
      @private_memos.each_pair{|target, memos| memos.delete_if{|memo| (memo.lifetime -= 1) <= 0}}
      @private_memos.delete_if{|target, memos| memos.empty?}
    end
  end

  # Memoize a public memo. Rejects memos for the bot itself
  # and for people already in the channel.
  def memoize(msg, nick, memo)
    msg.reply("Nice try. Forget it.") and return if nick == bot.nick
    msg.reply("#{nick} is already in here, you can tell him directly.") and return if msg.channel.has_user?(nick)

    @public_mutex.synchronize do
      bot.debug("Remembering a memo from #{msg.user.nick} for #{nick}")
      @public_memos[nick] << Memo.new(@max_lifetime, memo, msg.user, msg.channel)
    end

    msg.reply("OK, I'll notify #{nick} when (s)he enters the channel.", true)
  end

  # Memoize a private memo. Rejects memos for the bot itself.
  def private_memoize(msg, nick, memo)
    msg.reply("Nice try. Forget it.") and return if nick == bot.nick

    @private_mutex.synchronize do
      bot.loggers.info("Remembering a private memo from #{msg.user.nick} for #{nick}")
      @private_memos[nick] << Memo.new(@max_lifetime, memo, msg.user)
    end

    # Ensure we get up-to-date online information
    User(nick).monitor

    msg.reply("OK, I'll notify #{nick} when (s)he comes online.")
  end

end
