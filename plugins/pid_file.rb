# -*- coding: utf-8 -*-
#
# = Cinch PID file plugin
# This plugin is useful if you want to run Cinch as a daemon
# process. It creates a file containing Cinch’s process
# identifier (PID) when connecting to an IRC server, and deletes
# it on disconnection.
#
# == Dependencies
# None.
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins[Cinch::PidFile] = {
#     :path   => "/run/orrbot.pid,
#     :strict => true
#   }
#
# [path]
#   Where you want to have the PID file created. The directory
#   must be writable by Cinch.
# [strict (true)]
#   If this is true (the default), Cinch will refuse to start
#   if the PID file already exists, as this usually means that
#   another instance of Cinch is already running, but this may
#   also be the result of a kill-9 or the like. If you don’t
#   want this behaviour, simply set this option to false.
#
# == Author
# Marvin Gülker
#
# == License
# A PID file plugin for Cinch.
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

class Cinch::PidFile
  include Cinch::Plugin

  listen_to :connect,    :method => :create_pidfile
  listen_to :disconnect, :method => :delete_pidfile

  def create_pidfile(msg)
    config[:path]   || raise(ArgumentError, "No PID file path given!")
    config[:strict] ||= true
    abort "PID file exists: #{config[:path]}" if config[:strict] and File.exist?(config[:path])

    File.open(config[:path], "w"){|f| f.write($$)}
  end

  def delete_pidfile(msg)
    File.delete(config[:path])
  end

end
