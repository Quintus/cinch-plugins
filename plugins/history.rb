# -*- coding: utf-8 -*-
#
# = Cinch history plugin
# This plugin adds a non-persistant, short-time memory to Cinch that allows
# users to replay part of the session Cinch currently observers. This plugin
# can act in two different modes: The default mode is :max_messags, in which
# Cinch will only remember a fixed number of messages for replay; however, in
# a busy channel this may not provide enough information for finding one’s way
# into a discussion without having to raise the limit of remembered messages
# to some extraordinarily high value which this plugin is not meant for (if
# you want real, persistant logging, use the Logging plugin). Instead, you
# can switch to :max_age mode, in which Cinch will remember all messages
# whose age does not exceed a certain number of minutes.
#
# == Usage
# As a user, issue the following command privately to Cinch:
#
#   /msg cinch history
#
# Cinch will respond to you with a private message containing the history
# in the configured format.
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::History] = {
#     :mode => :max_messages,
#     :max_messages => 10,
#     # :max_age => 5,
#     :time_format => "%H:%M"
#   }
#
# [mode (:max_messages)]
#   Either :max_messages or :max_age, see explanations above.
# [max_messages (10)]
#   If you chose :max_messages mode, this is the number of messages
#   Cinch will remember.
# [max_age (5)]
#   If you chose :max_age mode, this is the maximum age in minutes
#   that a message may have before Cinch drops it from his memory.
#   The smallest useful value is 1, floating point values are not
#   allowed.
# [time_format ("%H:%M")]
#   When replaying history, Cinch prints the time stamp for each
#   message next to it, in the format specified via this configuration
#   option. See date(1) for possible directives.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A history plugin for Cinch.
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

class Cinch::History
  include Cinch::Plugin

  Entry = Struct.new(:time, :prefix, :message)

  listen_to :connect, :method => :on_connect
  listen_to :channel, :method => :on_channel
  listen_to :topic,   :method => :on_topic
  listen_to :away,    :method => :on_away
  listen_to :unaway,  :method => :on_unaway
  listen_to :action,  :method => :on_action
  listen_to :leaving, :method => :on_leaving
  listen_to :join,    :method => :on_join
  timer 60,           :method => :check_message_age
  match /history/,    :method => :replay, :react_on => :private, :use_prefix => false

  set :help, <<-HELP
/msg cinch history
  Sends the most recent messages of the channel to you via PM.
  HELP

  def on_connect(*)
    @mode          = config[:mode]         || :max_messages
    @max_messages  = config[:max_messages] || 10
    @max_age       = (config[:max_age]     || 5 ) * 60
    @timeformat    = config[:time_format]  || "%H:%M"
    @history_mutex = Mutex.new
    @history       = []
  end

  def on_channel(msg)
    return if msg.message.start_with?("\u0001")

    @history_mutex.synchronize do
      @history << Entry.new(msg.time, msg.user.nick, msg.message)

      if @mode == :max_messages
        # In :max_messages mode, let messages over the limit just
        # fall out of the history.
        @history.shift if @history.length > @max_messages
      end
    end
  end

  def on_topic(msg)
    @history_mutex.synchronize do
      @history << Entry.new(msg.time, "##", "#{msg.user.nick} changed the topic to “#{msg.channel.topic}”")
    end
  end

  def on_away(msg)
    @history_mutex.synchronize do
      @history << Entry.new(msg.time, "##", "#{msg.user.nick} is away (“#{msg.message}”)")
    end
  end

  def on_unaway(msg)
    @history_mutex.synchronize do
      @history << Entry.new(msg.time, "##" "#{msg.user.nick} is back")
    end
  end

  def on_action(msg)
    return unless msg.message =~ /^\u0001ACTION(.*?)\u0001/

    @history_mutex.synchronize do
      @history << Entry.new(msg.time, "**", "#{msg.user.nick} #{$1.strip}")
    end
  end

  def on_leaving(msg, user)
    @history_mutex.synchronize do
      @history << Entry.new(msg.time, "<=", "#{user.nick} left the channel")
    end
  end

  def on_join(msg)
    @history_mutex.synchronize do
      @history << Entry.new(msg.time, "=>", "#{msg.user.nick} entered the channel")
    end
  end

  # In :max_age mode, remove messages from the history older than
  # the threshold.
  def check_message_age
    return unless @mode == :max_age

    @history_mutex.synchronize do
      @history.delete_if{|entry| Time.now - entry.time > @max_age}
    end
  end

  def replay(msg)
    # Informative preamble
    if @mode == :max_age
      msg.reply("Here are the messages of the last #@max_age seconds:")
    else
      msg.reply("Here are the last #{@history.count} messages:")
    end

    # Actual historic(al) response
    @history_mutex.synchronize do
      r = @history.reduce("") do |answer, entry|
        answer + format_entry(entry)
      end

      msg.reply(r.chomp)
    end
  end

  private

  def format_entry(entry)
    sprintf("[%s] %15s | %s\n", entry.time.strftime(@timeformat), entry.prefix, entry.message)
  end

end
