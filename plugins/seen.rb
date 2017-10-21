# -*- coding: utf-8 -*-
#
# = Cinch Seen plugin
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::Seen] = {
#     :file => "/var/cache/seen.yml",
#     :max_age => 60 * 60 * 24 * 365
#   }
#
# [file]
#   Where to store the message log. This is a required
#   argument.
# [max_age]
#   When to purge entries from the "seen" database. After
#   this amount of seconds since the last time someone was
#   seen has elapsed, the entry is deleted the next time
#   the "seen" database is changed. This is a privacy
#   feature, set to 0 to disable (not recommended). Required
#   argument.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# An seen info plugin for Cinch.
# Copyright © 2014, 2017 Marvin Gülker
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

require "yaml"

class Cinch::Seen
  include Cinch::Plugin

  SeenInfo = Struct.new(:time, :nick, :channel, :message)
  FILEMUTEX = Mutex.new

  match /seen (.*)/
  listen_to :connect, :method => :on_connect
  listen_to :channel, :method => :on_channel

  def on_connect(*)
    raise("Missing required argument: :file")    unless config[:file]
    raise("Missing required argument: :max_age") unless config[:max_age]
  end

  def on_channel(msg)
    return if msg.message.start_with?("\u0001") # ACTION

    add_seen(msg.time, msg.channel.name, msg.user.nick, msg.message.strip)
  end

  def execute(msg, nick)
    if nick == bot.nick
      msg.reply "Self-reference err err tilt BOOOOM"
      return
    end

    if info = find_last_message(nick)
      msg.reply("I have last seen #{nick} in #{info.channel} on #{info.time} saying: #{info.message}")
    else
      msg.reply("I have not seen #{nick} saying something as far as I am configured to remember.")
    end
  end

  private

  def add_seen(timestamp, channel, nickname, message)
    FILEMUTEX.synchronize do
      hsh = File.exist?(config[:file]) ? YAML.load_file(config[:file]) : {}
      hsh[nickname] = {"time" => timestamp, "channel" => channel, "message" => message}

      if config[:max_age] > 0
        old_records = []
        hsh.each_pair do |nick, entry|
          if Time.now - entry["time"] >= config[:max_age]
            old_records << nick
          end
        end

        old_records.each{|nick| hsh.delete(nick)}
      end

      File.open(config[:file], "w"){|f| YAML.dump(hsh, f)}
    end
  end

  def find_last_message(nick)
    FILEMUTEX.synchronize do
      hsh = YAML.load_file(config[:file])
      return nil unless hsh.has_key?(nick)

      SeenInfo.new(hsh[nick]["time"], nick, hsh[nick]["channel"], hsh[nick]["message"])
    end
  end

end
