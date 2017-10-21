# -*- coding: utf-8 -*-
#
# = Cinch Seen plugin
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::History] = {
#     :file => "/var/cache/seen.yml"
#   }
#
# [file]
#   Where to store the message log. This is a required
#   argument.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# An seen info plugin for Cinch.
# Copyright © 2014 Marvin Gülker
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
    raise("Missing required argument: :file") unless config[:file]
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
      msg.reply("I have not yet seen #{nick} saying something.")
    end
  end

  private

  def add_seen(timestamp, channel, nickname, message)
    FILEMUTEX.synchronize do
      hsh = File.exist?(config[:file]) ? YAML.load_file(config[:file]) : {}
      hsh[nickname] = {"time" => timestamp, "channel" => channel, "message" => message}
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
