# -*- coding: utf-8 -*-
#
# = Cinch FIFO plugin
# Create a gateway to IRC on your filesystem! This Cinch
# plugin creates a named pipe (a FIFO) at the path specified
# in the configuration. After it has been successfully opened,
# you can redirect any program’s output into the FIFO, causing
# Cinch to paste the output into all IRC channels it currently
# is in.
#
# == Dependencies
# * Gem: mkfifo
# * A POSIX-conforming operating system. This definitely
#   excludes Microsoft Windows.
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins[Cinch::Fifo] = {
#     :path => "/tmp/irc",
#     :mode => 0666
#   }
#
# [path]
#   Where to open the named pipe. Cinch must have write
#   access to the directory containing this file.
# [mode]
#   File mode to set on the pipe. Depending on who you
#   want to be able to write to the pipe you may choose
#   anything from 0666 (read-write for anybody) to
#   0200 (write-only for the owner). See chmod(1) for
#   possible modes (and beware the leading zero, this is
#   usually an octal number).
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A named-pipe plugin for Cinch.
# Copyright © 2012 Marvin Gülker
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "mkfifo"

# Named pipe plugin for Cinch.
class Cinch::Fifo
  include Cinch::Plugin
  listen_to :connect,    :method => :open_fifo
  listen_to :disconnect, :method => :close_fifo

  def open_fifo(msg)
    File.mkfifo(config[:path] || raise(ArgumentError, "No FIFO path given!"))
    File.chmod(config[:mode] || 0666, config[:path])

    File.open(config[:path], "r+") do |fifo|
      bot.info "Opened named pipe (FIFO) at #{config[:path]}"

      fifo.each_line do |line|
        msg = line.strip
        bot.debug "Got message from the FIFO: #{msg}"
        bot.channels.each{|channel| channel.send(msg)}
      end
    end

  end

  def close_fifo(msg)
    File.delete(config[:path])
    bot.info "Deleted named pipe #{config[:path]}."
  end

end
