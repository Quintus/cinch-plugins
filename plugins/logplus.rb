# -*- coding: utf-8 -*-
#
# = Cinch advanced message logging plugin
# Fully-featured logging module for cinch with HTML logs.
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::LogPlus] = {
#     :logdir  => "/tmp/htmllogs", # required
#     :timelogformat => "%H:%M",
#     :extrahead => ""
#   }
#
# [logdir]
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
# Copyright © 2014,2015,2017 Marvin Gülker
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

require "cgi"
require "time"
require_relative "mirc_codes_converter"

class Cinch::LogPlus
  include Cinch::Plugin

  # Hackish mini class for catching Cinch’s outgoing messages, which
  # are not covered by the :channel event. It’d be impossible to log
  # what the bot says otherwise, and compared to monkeypatching Cinch
  # this is still the cleaner approach.
  class OutgoingLogger < Cinch::Logger

    # Creates a new instance. The block passed to this method will
    # be called for each outgoing message. It will receive the
    # outgoing message (string), the level (symbol), and whether it’s
    # a NOTICE (true) or PRIVMSG (false) as arguments.
    def initialize(&callback)
      super(File.open("/dev/null"))
      @callback = callback
    end

    # Logs a message. Calls the callback if the +event+ is
    # an "outgoing" event.
    def log(messages, event = :debug, level = event)
      if event == :outgoing
        Array(messages).each do |msg|
          if msg =~ /^PRIVMSG .*?:/
            @callback.call($', level, false)
          elsif msg =~ /^NOTICE .*?:/
            @callback.call($', level, true)
          end
        end
      end
    end

  end

  set :required_options, [:logdir]

  match /log stop/, :method => :cmd_log_stop
  match /log start/, :method => :cmd_log_start

  listen_to :channel,    :method => :log_public_message
  listen_to :topic,      :method => :log_topic
  listen_to :join,       :method => :log_join
  listen_to :leaving,    :method => :log_leaving
  listen_to :nick,       :method => :log_nick
  listen_to :mode_change,:method => :log_modechange
  timer 60,              :method => :check_midnight

  # Default CSS used when the :extrahead option is not given.
  # Some default styling.
  DEFAULT_CSS = <<-CSS.freeze
    <style type="text/css">
    body {
       background-color: white;
       font-family: sans-serif;
    }
    .chattable {
        border-collapse: collapse;
        border-top: 1px solid black;
        border-bottom: 1px solid black;
        width: 100%;
     }
    .chattable tr:target {
      background-color: yellow;
    }
    .chattable tr:hover {
      background-color: #ddddff;
    }
    .chattable tr:target:hover {
      background-color: #ff9999;
    }
    .chattable tr td {
      vertical-align: top;
      white-space: nowrap;
      min-width: 10px;
    }
    .chattable tr td:last-child {
      width: 100%;
      white-space: normal;
    }
    .msgnick {
        border-right: 1px solid black;
        padding-right: 8px;
        padding-left: 4px;
    }
    .msgtime a {
      text-decoration: none;
      color: black;
    }
    .msgtime a:hover, .msgtime a:active {
      color: red;
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
    .msgnickchange {
       padding-left: 8px;
       font-weight: bold;
       font-style: italic;
       color: #820002;
    }
    .msgmode {
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
    .nickjoins {
       color: green;
    }
    .nickleaves {
       color: red;
    }
    .navi {
      font-size: small;
      margin-bottom: 1px;
    }
    .navi-previous {
      float: left;
    }
    .navi-next {
      float: right;
    }
    .navi-index {
      text-align: center;
    }
    .navi p {
      margin: 0px;
      padding: 0px;
    }
    </style>
  CSS

  def initialize(*)
    super
    # Add our hackish logger for catching outgoing messages.
    bot.loggers.push(OutgoingLogger.new(&method(:log_own_message)))

    @stopped         = false
    @last_time_check = Time.now
    @htmllogfile     = nil
    @filemutex       = Mutex.new

    reopen_log

    # Disconnect event is not always issued, so we just use
    # Ruby’s own at_exit hook for cleanup.
    at_exit { @filemutex.synchronize { @htmllogfile.close } }
  end

  # Timer target. Creates new logfiles if midnight has been crossed
  # since the last time it was called. This has to be called by a
  # timer, since otherwise there'd be no files for days on which
  # nothing happened. That would mean that days where nothing happened
  # would be undistinguishable from days where the bot was not
  # running at all.
  def check_midnight
    time = Time.now

    # If day changed, finish this day’s logfiles and start new ones.
    reopen_log unless @last_time_check.day == time.day

    @last_time_check = time
  end

  def timelogformat
    config[:timelogformat] || "%H:%M"
  end

  def cmd_log_stop(msg)
    if @stopped
      msg.reply "I do not log currently."
      return
    end

    unless msg.channel.opped?(msg.user)
      msg.reply "You are not authorized to command me so!"
      return
    end

    msg.reply "I see. I will close down my ears so everything that follows remains private."
    @stopped = true
  end

  def cmd_log_start(msg)
    unless @stopped
      msg.reply "I am logging the conversation already."
      return
    end

    unless msg.channel.opped?(msg.user)
      msg.reply "You are not authorized to command me so!"
      return
    end

    msg.reply "OK. Everything that follows will be logged again."
    @stopped = false
  end

  # Target for all public channel messages/actions not issued by the bot.
  def log_public_message(msg)
    return if @stopped

    @filemutex.synchronize do
      if msg.action?
        log_html_action(msg)
      else
        log_html_message(msg)
      end
    end
  end

  # Target for all messages issued by the bot.
  def log_own_message(text, level, is_notice)
    return if @stopped

    @filemutex.synchronize do
      log_own_htmlmessage(text, is_notice)
    end
  end

  # Target for /topic commands.
  def log_topic(msg)
    return if @stopped

    @filemutex.synchronize do
      log_html_topic(msg)
    end
  end

  def log_nick(msg)
    return if @stopped

    @filemutex.synchronize do
      log_html_nick(msg)
    end
  end

  def log_join(msg)
    return if @stopped

    @filemutex.synchronize do
      log_html_join(msg)
    end
  end

  def log_leaving(msg, leaving_user)
    return if @stopped

    @filemutex.synchronize do
      log_html_leaving(msg, leaving_user)
    end
  end

  def log_modechange(msg, ary)
    return if @stopped

    @filemutex.synchronize do
      log_html_modechange(msg, ary)
    end
  end

  private

  # Helper method for generating the file basename for the logfiles
  # and appending the given extension (which must include the dot).
  # The filename is generated for the current day by default, but this
  # can be changed using the second parameter.
  def genfilename(ext, time = Time.now)
    time.strftime("%Y-%m-%d") + ext
  end

  # Helper method for determining the status of the user sending
  # the message. Returns one of the following strings:
  # "opped", "halfopped", "voiced", "".
  def determine_status(msg, user = msg.user)
    return "" unless msg.channel # This is nil for leaving users
    return "" unless user # server-side NOTICEs

    user = user.name if user.kind_of?(Cinch::User)

    if user == bot.nick
      "selfbot"
    elsif msg.channel.opped?(user)
      "opped"
    elsif msg.channel.half_opped?(user)
      "halfopped"
    elsif msg.channel.voiced?(user)
      "voiced"
    else
      ""
    end
  end

  # Helper method that escapes any HTML snippets in the message
  # (prevents XSS attacks) and scans for URLs, replacing them
  # with a proper HTML <a> tag.
  def process_message(message)
    urls = []
    # Step 1: Extract all URLs and replace them with a placeholder.
    message = message.gsub(%r!(https?|ftps?|gopher|irc|xmpp|sip)://[[[:alnum:]]\.,\-_#\+&%$/\(\)\[\]\?=]+:!) do
      urls.push($&)
      "\x1a" # ASCII SUB, nobody is going to use this in IRC
    end

    # Step 2: Escape any HTML to prevent XSS and similar things.
    # This leaves the placeholders untouched. CGI.escape_html
    # would, if applied to the URLs, escape things like &, which
    # are valid in an URL.
    message = CGI.escape_html(message)

    # Step 3: Now re-replace the placeholders with the
    # extracted URLs converted to HTML.
    message = message.gsub(/\x1a/) do
      if url = urls.shift # Single = intended
        %Q!<a class="msglink" href="#{url}">#{CGI.escape_html(url)}</a>!
      else # This happens if a user really did use an ASCII SUB.
        "[parse error]"
      end
    end

    message
  end

  # Finish a day’s logfiles and open new ones.
  def reopen_log
    @filemutex.synchronize do
      # If the bot was restarted, an HTML logfile already exists.
      # We want to continue that one rather than overwrite.
      htmlfile = File.join(config[:logdir], genfilename(".log.html"))
      if @htmllogfile
        if File.exist?(htmlfile)
          # This shouldn’t happen (would be a useless call of reopen_log)
          # nothing, continue using current file
        else
          # Normal midnight log rotation
          finish_html_file
          @htmllogfile.close

          @htmllogfile = File.open(htmlfile, "w")
          @htmllogfile.sync = true
          start_html_file
        end
      else
        if File.exist?(htmlfile)
          # Bot restart on the same day
          @htmllogfile = File.open(htmlfile, "a")
          @htmllogfile.sync = true
          # Do not write preamble, continue with current file
        else
          # First bot startup on this day
          @htmllogfile = File.open(htmlfile, "w")
          @htmllogfile.sync = true
          start_html_file
        end
      end
    end

    bot.info("Opened new channel logfile.")
  end

  # Logs the given message to the HTML logfile.
  # Does NOT acquire the file mutex!
  def log_html_message(msg)
    converter = Cinch::MircCodesConverter.new
    anchor = timestamp_anchor(msg.time)
    str = <<-HTML
      <tr id="#{anchor}">
        <td class="msgtime"><a href="##{anchor}">#{msg.time.strftime(timelogformat)}</a></td>
        <td class="msgnick #{determine_status(msg)}">#{msg.user}</td>
        <td class="msgmessage">#{converter.convert(process_message(msg.message))}</td>
      </tr>
    HTML

    @htmllogfile.write(str)
  end

  # Logs the given text to the plaintext logfile. Does NOT
  # acquire the file mutex!
  def log_own_htmlmessage(text, is_notice)
    time = Time.now
    anchor = timestamp_anchor(time)
    converter = Cinch::MircCodesConverter.new
    @htmllogfile.puts(<<-HTML)
      <tr id="#{anchor}">
        <td class="msgtime"><a href="##{anchor}">#{time.strftime(timelogformat)}</a></td>
        <td class="msgnick selfbot">#{bot.nick}</td>
        <td class="msgmessage">#{converter.convert(process_message(text))}</td>
      </tr>
    HTML
  end

  # Logs the given action to the HTML logfile Does NOT
  # acquire the file mutex!
  def log_html_action(msg)
    converter = Cinch::MircCodesConverter.new
    anchor = timestamp_anchor(msg.time)
    str = <<-HTML
      <tr id="#{anchor}">
        <td class="msgtime"><a href="##{anchor}">#{msg.time.strftime(timelogformat)}</a></td>
        <td class="msgnick nickaction">*</td>
        <td class="msgaction"><span class="actionnick #{determine_status(msg)}">#{msg.user.name}</span>&nbsp;#{converter.convert(process_message(msg.action_message))}</td>
      </tr>
    HTML

    @htmllogfile.write(str)
  end

  # Logs the given topic change to the HTML logfile. Does NOT
  # acquire the file mutex!
  def log_html_topic(msg)
    anchor = timestamp_anchor(msg.time)
    @htmllogfile.write(<<-HTML)
      <tr id="#{anchor}">
        <td class="msgtime"><a href="##{anchor}">#{msg.time.strftime(timelogformat)}</a></td>
        <td class="msgnick nickaction">*</td>
        <td class="msgtopic"><span class="actionnick #{determine_status(msg)}">#{msg.user.name}</span>&nbsp;changed the topic to “#{process_message(msg.message)}”.</td>
      </tr>
    HTML
  end

  def log_html_nick(msg)
    oldnick = msg.raw.match(/^:(.*?)!/)[1]
    anchor = timestamp_anchor(msg.time)
    @htmllogfile.write(<<-HTML)
      <tr id="#{anchor}">
        <td class="msgtime"><a href="##{anchor}">#{msg.time.strftime(timelogformat)}</a></td>
        <td class="msgnick nickaction">─</td>
        <td class="msgnickchange"><span class="actionnick #{determine_status(msg, oldnick)}">#{oldnick}</span>&nbsp;is now known as <span class="actionnick #{determine_status(msg, msg.message)}">#{msg.message}</span>.</td>
      </tr>
    HTML
  end

  def log_html_join(msg)
    anchor = timestamp_anchor(msg.time)
    @htmllogfile.write(<<-HTML)
      <tr id="#{anchor}">
        <td class="msgtime"><a href="##{anchor}">#{msg.time.strftime(timelogformat)}</a></td>
        <td class="msgnick nickjoins">─►</td>
        <td class="msgjoin"><span class="actionnick #{determine_status(msg)}">#{msg.user.name}</span>&nbsp;entered #{msg.channel.name}.</td>
      </tr>
    HTML
  end

  def log_html_leaving(msg, leaving_user)
    if msg.channel?
      text = "left #{msg.channel.name} (#{process_message(msg.message)})"
    else
      text = "left the IRC network (#{process_message(msg.message)})"
    end

    anchor = timestamp_anchor(msg.time)
    @htmllogfile.write(<<-HTML)
      <tr id="#{anchor}">
        <td class="msgtime"><a href="##{anchor}">#{msg.time.strftime(timelogformat)}</a></td>
        <td class="msgnick nickleaves">◄─</td>
        <td class="msgleave"><span class="actionnick #{determine_status(msg)}">#{leaving_user.name}</span>&nbsp;#{text}.</td>
      </tr>
    HTML
  end

  def log_html_modechange(msg, changes)
    adds = changes.select{|subary| subary[0] == :add}
    removes = changes.select{|subary| subary[0] == :remove}

    change = ""
    unless removes.empty?
      change += removes.reduce("-"){|str, subary| str + subary[1] + (subary[2] ? " " + subary[2] : "")}.rstrip
    end
    unless adds.empty?
      change += adds.reduce("+"){|str, subary| str + subary[1] + (subary[2] ? " " + subary[2] : "")}.rstrip
    end

    anchor = timestamp_anchor(msg.time)
    @htmllogfile.write(<<-HTML)
      <tr id="#{anchor}">
        <td class="msgtime"><a href="##{anchor}">#{msg.time.strftime(timelogformat)}</a></td>
        <td class="msgnick nickmodechange">─</td>
        <td class="msgmode">Mode #{change} by <span class="actionnick #{determine_status(msg)}">#{msg.user.name}</span>.</td>
      </tr>
    HTML
  end

  def timestamp_anchor(time)
    "msg-#{time.iso8601}"
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
#{config[:extrahead] || DEFAULT_CSS}
  </head>
  <body>
    <h1>Chatlogs for #{bot.config.channels.first} on #{bot.config.server}, #{Time.now.strftime('%Y-%m-%d')}</h1>
    <p>Nick colors:</p>
    <dl>
      <dt class="opped">Nick</dt><dd>Channel operator (+o)</dd>
      <dt class="halfopped">Nick</dt><dd>Channel half-operator (+h)</dd>
      <dt class="voiced">Nick</dt><dd>Nick is voiced (+v)</dd>
      <dt class="selfbot">Nick</dt><dd>The logging bot itself</dd>
      <dt>Nick</dt><dd>Normal nick</dd>
    </dl>
    <p>All times are UTC#{Time.now.strftime('%:z')}.</p>
    <table class="chattable">
    HTML

    # On midnight rotation, add the topic to the logs (can be hard to find otherwise).
    unless bot.channels.empty?
      @htmllogfile.puts <<-HTML
      <tr>
        <td class="msgtime">#{Time.now.strftime(timelogformat)}</td>
        <td class="msgnick">(system message)</td>
        <td class="msgtopic">The topic for this channel is currently “#{process_message(bot.channels.first.topic)}”.</td>
      </tr>
      HTML
    end
  end

  # Write the end bloat to the HTML log file.
  # Does NOT acquire the file mutex!
  def finish_html_file
    now          = Time.now
    previousname = genfilename(".log.html", now - 60 * 60 * 24)
    nextname     = genfilename(".log.html", now + 60 * 60 * 24)
    @htmllogfile.puts <<-HTML
    </table>
    <div class="navi">
      <p class="navi-previous"><a href="#{previousname}">◄ Previous</a></p>
      <p class="navi-next"><a href="#{nextname}">Next ►</a></p>
      <p class="navi-index"><a href="..">◆ Index</a></p>
      <div style="clear: both"></div>
    </div>
  </body>
</html>
    HTML
  end

end
