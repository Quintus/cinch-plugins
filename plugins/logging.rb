# -*- coding: utf-8 -*-
#
# = Cinch message logging plugin
# Cinch’s normal logfiles are fine for (debugging) analysis,
# but you generally don’t want to give them to the public. If
# you intend to provide public logging for a channel via Cinch,
# you can use this plugin which creates a logfile containing only
# the public messages (with timestamps).
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::Logging] = {
#     :logfile => "/tmp/public.log", # required
#     :timeformat => "%H:M",
#     :format => "<%{time}> %{nick}: %{msg},
#     :midnight_message => "=== New day: %Y-%m-%d ==="
#   }
#
# [logfile]
#   Where to store the log. Cinch must have write access
#   to this file.
# [timeformat ("%H:%M")]
#   Format of the timestamp used in messages. Percent escapes are
#   as described for date(1). %% gives a literal percent.
# [format("<%{time}> %{nick}: %{msg}")]
#   Format of the log messages. %{time} is replaced by the
#   timestamp (which is formatted itself accoding to +timeformat+),
#   %{nick} with the name of the speaker, and %{msg} with the
#   actual message. %% gives a literal percent.
# [midnight_message ("=== some long string ===")]
#   This line is printed to the log on midnight. It undergoes
#   the usual time formatting, so you can use %d, %Y, and so on.
#
# == Configuration
# None.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A logging plugin for Cinch.
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

class Cinch::Logging
  include Cinch::Plugin

  set :required_options, [:logfile]

  listen_to :connect,    :method => :setup
  listen_to :disconnect, :method => :cleanup
  listen_to :channel,    :method => :log_public_message
  timer 60,              :method => :check_midnight

  def setup(*)
    @logfile          = File.open(config[:logfile], "a")
    @timeformat       = config[:timeformat]       || "%H:%M"
    @logformat        = config[:format]           || "<%{time}> %{nick}: %{msg}"
    @midnight_message = config[:midnight_message] || "=== The dawn of a new day: %Y-%m-%d ==="
    @last_time_check  = Time.now

    bot.debug("Opened message logfile at #{config[:logfile]}")
  end

  def cleanup(*)
    @logfile.close
    bot.debug("Closed message logfile.")
  end

  def check_midnight
    time = Time.now
    @logfile.puts(time.strftime(@midnight_message)) if time.day != @last_time_check.day
    @last_time_check = time
  end

  def log_public_message(msg)
    time = Time.now.strftime(@timeformat)
    @logfile.puts(sprintf(@logformat,
                          :time => time,
                          :nick => msg.user.name,
                          :msg  => msg.message))
  end

end
