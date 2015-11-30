# -*- coding: utf-8 -*-
#
# = Cinch Channel Record plugin
#
# This plugin makes Cinch print a message to the channel when
# the number of nicks in the channel is as high as it was
# never before. Also adds a `record' command for retrieval
# of the current record.
#
# When cinch joins the channel first after enabling this plugin,
# the current nick count is taken as the baseline (and no
# record message is printed).
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::ChannelRecord] = {
#     :file => "/var/cache/record.dat"
#   }
#
# [file]
#   Where to store the current record info.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A channel nick record plugin for cinch.
# Copyright © 2015 Marvin Gülker
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

class Cinch::ChannelRecord
  include Cinch::Plugin

  Record = Struct.new(:count, :timestamp)

  match /record$/
  listen_to :connect, :method => :on_connect
  listen_to :join,    :method => :on_join

  def on_connect(*)
    @filepath = config[:file] || raise("Missing required argument: :file")
    @filemutex = Mutex.new
  end

  def on_join(msg)
    @filemutex.synchronize do
      curcount = msg.channel.users.count

      if record = current_record # Single = intended
        if curcount > record.count
          new_max_nick_count(curcount)
          msg.reply("We reached a new nick record with #{curcount} nicks in the channel!")
          msg.reply("This supersedes the old record of #{record.count} nicks on #{record.timestamp}.")
        end
      else
        # No record saved yet, use current count as a base line.
        new_max_nick_count(curcount)
      end
    end
  end

  def execute(msg)
    @filemutex.synchronize do
      record = current_record
      msg.reply("The current nick record is #{record.count}, reached on #{record.timestamp}.")
    end
  end

  private

  def current_record
    if File.file?(@filepath)
      ary = File.read(@filepath).split("|").map(&:to_i)
      Record.new(ary[0], Time.at(ary[1]))
    else
      nil
    end
  end

  def new_max_nick_count(count)
    File.open(@filepath, "w"){|f| f.write("#{count.to_s}|#{Time.now.to_i}")}
  end

end
