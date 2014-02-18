# -*- coding: utf-8 -*-
#
# = Cinch advanced message logging plugin
# Fully-featured logging module for cinch with both
# plaintext and HTML logs.
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::LogPlus] = {
#     :plainlogdir => "/tmp/logs/plainlogs", # required
#     :htmllogdir  => "/tmp/logs/htmllogs", # required
#     :timelogformat => "%H:%M",
#     :extrahead => ""
#   }
#
# [plainlogdir]
#   This required option specifies where the plaintext logfiles
#   are kept.
# [htmllogdir]
#   This required option specifies where the HTML logfiles
#   are kept.
# [timelogformat ("%H:%M")]
#   Timestamp format for the messages. The usual date(1) format
#   string.
# [extrahead ("much css")]
#   Extra snippet of HTML to include in the HTML header of
#   each file. The default is a snippet of CSS to nicely
#   format the log table, but you can overwrite this completely
#   by specifying this option. It could also include Javascript
#   if you wanted. See Cinch::LogPlus::DEFAULT_CSS for the default
#   value of this option.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# An advanced logging plugin for Cinch.
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

# Cinch’s :channel event does not include messages Cinch sent itself.
# Especially for logging this is really bad, because the messages sent
# by the bot wouldn’t show up in the generated logfiles. Therefore, this
# monkeypatch adds a new :outmsg event to Cinch that is fired each time
# a PRIVMSG or NOTICE is issued by the bot. It takes the following
# arguments:
#
# [msg]
#   Always nil, this did not come from the IRC server.
# [text]
#   The message we are about to send.
# [notice]
#   If true, the message is a NOTICE. Otherwise, it's a PRIVMSG.
# [privatemsg]
#   If true, the message is to be sent directly to a user rather
#   than to a public channel.
class Cinch::Target

  # Override Cinch’s default message sending so so have an event
  # to listen for for our own outgoing messages.
  alias old_msg msg
  def msg(text, notice = false)
    @bot.handlers.dispatch(:outmsg, nil, text, notice, self.kind_of?(Cinch::User))
    old_msg(text, notice)
  end

end

class Cinch::LogPlus
  include Cinch::Plugin

  set :required_options, [:plainlogdir, :htmllogdir]

  listen_to :connect,    :method => :startup
  listen_to :channel,    :method => :log_public_message
  listen_to :outmsg,     :method => :log_own_message
  listen_to :topic,      :method => :log_topic
  listen_to :join,       :method => :log_join
  listen_to :leaving,    :method => :log_leaving
  timer 60,              :method => :check_midnight

  # Default CSS used when the :extrahead option is not given.
  # Some default styling.
  DEFAULT_CSS = <<-CSS
    <style type="text/css">
    body {
       background-color: white;
    }
    .chattable {
        border-collapse: collapse;
     }
    .msgnick {
        border-right: 1px solid black;
        padding-right: 8px;
        padding-left: 4px;
    }
    .opped {
        color: #006e21;
        font-weight: bold;
     }
     .halfopped {
        color: #006e21;
     }
    .voiced {
        color: #00a5ff;
        font-style: italic;
     }
     .selfbot {
       color: #920002;
     }
    .msgmessage {
        padding-left: 8px;
    }
    .msgaction {
       padding-left: 8px;
       font-style: italic;
    }
    .msgtopic {
       padding-left: 8px;
       font-weight: bold;
       font-style: italic;
       color: #920002;
    }
    .msgjoin {
       padding-left: 8px;
       font-style: italic;
       color: green;
    }
    .msgleave {
       padding-left: 8px;
       font-style: italic;
       color: red;
    }
    </style>
  CSS

  # Called on connect, sets up everything.
  def startup(*)
    @plainlogdir = config[:plainlogdir]
    @htmllogdir  = config[:htmllogdir]
    @timelogformat = config[:timelogformat] = "%H:%M"
    @extrahead = config[:extrahead] || DEFAULT_CSS

    @last_time_check = Time.now
    @plainlogfile    = nil
    @htmllogfile     = nil
    @messagenum      = 0

    @filemutex = Mutex.new

    reopen_logs

    # Disconnect event is not always issued, so we just use
    # Ruby’s own at_exit hook for cleanup.
    at_exit do
      @filemutex.synchronize do
        finish_html_file
        @htmllogfile.close
        @plainlogfile.close
      end
    end
  end

  # Timer target. Creates new logfiles if midnight has been crossed.
  def check_midnight
    time = Time.now

    # If day changed, finish this day’s logfiles and start new ones.
    reopen_logs unless @last_time_check.day == time.day

    @last_time_check = time
  end

  # Target for all public channel messages/actions not issued by the bot.
  def log_public_message(msg)
    @filemutex.synchronize do
      if msg.action?
        log_plaintext_action(msg)
        log_html_action(msg)
      else
        log_plaintext_message(msg)
        log_html_message(msg)
      end
    end
  end

  # Target for all messages issued by the bot.
  def log_own_message(msg, text, is_notice, is_private)
    return if is_private # Do not log messages not targetted at the channel

    @filemutex.synchronize do
      log_own_plainmessage(text, is_notice)
      log_own_htmlmessage(text, is_notice)
    end
  end

  # Target for /topic commands.
  def log_topic(msg)
    @filemutex.synchronize do
      log_plaintext_topic(msg)
      log_html_topic(msg)
    end
  end

  def log_join(msg)
    @filemutex.synchronize do
      log_plaintext_join(msg)
      log_html_join(msg)
    end
  end

  def log_leaving(msg, leaving_user)
    @filemutex.synchronize do
      log_plaintext_leaving(msg, leaving_user)
      log_html_leaving(msg, leaving_user)
    end
  end

  private

  # Helper method for generating the file basename for the logfiles
  # and appending the given extension (which must include the dot).
  def genfilename(ext)
    Time.now.strftime("%Y-%m-%d") + ext
  end

  # Helper method for determining the status of the user sending
  # the message. Returns one of the following strings:
  # "opped", "halfopped", "voiced", "".
  def determine_status(msg)
    return "" unless msg.channel # This is nil for leaving users
    return "" unless msg.user # server-side NOTICEs

    if msg.user.name == bot.nick
      "selfbot"
    elsif msg.channel.opped?(msg.user)
      "opped"
    elsif msg.channel.half_opped?(msg.user)
      "halfopped"
    elsif msg.channel.voiced?(msg.user)
      "voiced"
    else
      ""
    end
  end

  # Finish a day’s logfiles and open new ones. Note that for the HTML
  # files, appending is impossible — if you call this method more than
  # once a day, any existing HTML log file will be overwritten.
  # This method DOES acquire the file mutex.
  def reopen_logs
    @filemutex.synchronize do
      # Close plain file if existing (startup!)
      @plainlogfile.close if @plainlogfile

      # Finish & Close HTML file if existing (startup!)
      if @htmllogfile
        finish_html_file
        @htmllogfile.close
      end

      # New files
      bot.info("Opening new logfiles.")
      @plainlogfile = File.open(File.join(@plainlogdir, genfilename(".log")), "a")
      @htmllogfile  = File.open(File.join(@htmllogdir, genfilename(".log.html")), "w") # Can't incrementally update HTML files

      # Log files should always be written directly to disk
      @plainlogfile.sync = true
      @htmllogfile.sync = true

      # Begin HTML log file
      @messagenum = 0
      start_html_file
    end
  end

  # Logs the given message to the plaintext logfile.
  # Does NOT acquire the file mutex!
  def log_plaintext_message(msg)
    @plainlogfile.puts(sprintf("%{time} %{nick} | %{msg}",
                               :time => msg.time.strftime(@timelogformat),
                               :nick => msg.user.to_s,
                               :msg => msg.message))
  end

  # Logs the given message to the HTML logfile.
  # Does NOT acquire the file mutex!
  def log_html_message(msg)
    # Used for creating unique message IDs, see below
    @messagenum += 1

    str = <<-HTML
      <tr id="msg-#@messagenum">
        <td class="msgtime">#{msg.time.strftime(@timelogformat)}</td>
        <td class="msgnick #{determine_status(msg)}">#{msg.user}</td>
        <td class="msgmessage">#{msg.message}</td>
      </tr>
    HTML

    @htmllogfile.write(str)
  end

  # Logs the given text to the plaintext logfile. Does NOT
  # acquire the file mutex!
  def log_own_plainmessage(text, is_notice)
    @plainlogfile.puts(sprintf("%{time} %{nick} | %{msg}",
                               :time => Time.now.strftime(@timelogformat),
                               :nick => bot.nick,
                               :msg => text))
  end

  # Logs the given text to the plaintext logfile. Does NOT
  # acquire the file mutex!
  def log_own_htmlmessage(text, is_notice)
    @messagenum += 1

    @htmllogfile.puts(<<-HTML)
      <tr id="msg-#@messagenum">
        <td class="msgtime">#{Time.now.strftime(@timelogformat)}</td>
        <td class="msgnick selfbot">#{bot.nick}</td>
        <td class="msgmessage">#{text}</td>
      </tr>
    HTML
  end

  # Logs the given action to the plaintext logfile. Does NOT
  # acquire the file mutex!
  def log_plaintext_action(msg)
    @plainlogfile.puts(sprintf("%{time} **%{nick} %{msg}",
                               :time => msg.time.strftime(@timelogformat),
                               :nick => msg.user.name,
                               :msg => msg.action_message))
  end

  # Logs the given action to the HTML logfile Does NOT
  # acquire the file mutex!
  def log_html_action(msg)
    @messagenum += 1

    str = <<-HTML
      <tr id="msg-#@messagenum">
        <td class="msgtime">#{msg.time.strftime(@timelogformat)}</td>
        <td class="msgnick">*</td>
        <td class="msgaction"><span class="actionnick #{determine_status(msg)}">#{msg.user.name}</span>&nbsp;#{msg.action_message}</td>
      </tr>
    HTML

    @htmllogfile.write(str)
  end

  # Logs the given topic change to the HTML logfile. Does NOT
  # acquire the file mutex!
  def log_plaintext_topic(msg)
    @plainlogfile.puts(sprintf("%{time} *%{nick} changed the topic to “%{msg}”.",
                       :time => msg.time.strftime(@timelogformat),
                       :nick => msg.user.name,
                       :msg => msg.message))
  end

  # Logs the given topic change to the HTML logfile. Does NOT
  # acquire the file mutex!
  def log_html_topic(msg)
    @messagenum += 1

    @htmllogfile.write(<<-HTML)
      <tr id="msg-#@messagenum">
        <td class="msgtime">#{msg.time.strftime(@timelogformat)}</td>
        <td class="msgnick">*</td>
        <td class="msgtopic"><span class="actionnick #{determine_status(msg)}">#{msg.user.name}</span>&nbsp;changed the topic to “#{msg.message}”.</td>
      </tr>
    HTML
  end

  def log_plaintext_join(msg)
    @plainlogfile.puts(sprintf("%{time} -->%{nick} entered %{channel}.",
                               :time => msg.time.strftime(@timelogformat),
                               :nick => msg.user.name,
                               :channel => msg.channel.name))
  end

  def log_html_join(msg)
    @messagenum += 1

    @htmllogfile.write(<<-HTML)
      <tr id="msg-#@messagenum">
        <td class="msgtime">#{msg.time.strftime(@timelogformat)}</td>
        <td class="msgnick">--&gt;</td>
        <td class="msgjoin"><span class="actionnick #{determine_status(msg)}">#{msg.user.name}</span>&nbsp;entered #{msg.channel.name}.</td>
      </tr>
    HTML
  end

  def log_plaintext_leaving(msg, leaving_user)
    if msg.channel?
      text = "%{nick} left #{msg.channel.name} (%{msg})"
    else
      text = "%{nick} left the IRC network (%{msg})"
    end

    @plainlogfile.puts(sprintf("%{time} <--#{text}",
                               :time => msg.time.strftime(@timelogformat),
                               :nick => leaving_user.name,
                               :msg => msg.message))
  end

  def log_html_leaving(msg, leaving_user)
    @messagenum += 1

    if msg.channel?
      text = "left #{msg.channel.name} (#{msg.message})"
    else
      text = "left the IRC network (#{msg.message})"
    end

    @htmllogfile.write(<<-HTML)
      <tr id="msg-#@messagenum">
        <td class="msgtime">#{msg.time.strftime(@timelogformat)}</td>
        <td class="msgnick">&lt;--</td>
        <td class="msgleave"><span class="actionnick #{determine_status(msg)}">#{leaving_user.name}</span>&nbsp;#{text}.</td>
      </tr>
    HTML
  end

  # Write the start bloat HTML to the HTML log file.
  # Does NOT acquire the file mutex!
  def start_html_file
    @htmllogfile.puts <<-HTML
<!DOCTYPE HTML>
<html>
  <head>
    <title>Chatlogs #{bot.config.channels.first} #{Time.now.strftime('%Y-%m-%d')}</title>
    <meta charset="utf-8"/>
#{@extrahead}
  </head>
  <body>
    <h1>Chatlogs for #{bot.config.channels.first}, #{Time.now.strftime('%Y-%m-%d')}</h1>
    <p>Nick colors:</p>
    <dl>
      <dt class="opped">Nick</dt><dd>Channel operator (+o)</dd>
      <dt class="halfopped">Nick</dt><dd>Channel half-operator (+h)</dd>
      <dt class="voiced">Nick</dt><dd>Nick is voiced (+v)</dd>
      <dt class="selfbot">Nick</dt><dd>The logging bot itself</dd>
      <dt>Nick</dt><dd>Normal nick</dd>
    </dl>
    <hr/>
    <table class="chattable">
    HTML
  end

  # Write the end bloat to the HTML log file.
  # Does NOT acquire the file mutex!
  def finish_html_file
    @htmllogfile.puts <<-HTML
    </table>
  </body>
</html>
    HTML
  end

end
