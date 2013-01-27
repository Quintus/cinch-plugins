# -*- coding: utf-8 -*-
#
# = Cinch help plugin
# This plugin parses the +help+ option of all plugins registered with
# the bot when connecting to the server and provides a nice interface
# for querying these help strings via the 'help' command.
#
# == Commands
# [cinch help]
#   Print the intro message and list all plugins.
# [cinch help <plugin>]
#   List all commands with explanations for a plugin.
# [cinch help search <query>]
#   List all commands with explanations that contain <query>.
#
# == Dependencies
# None.
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins[Cinch::Fifo] = {
#     :intro => "%s at your service."
#   }
#
# [intro]
#   First message posted when the user issues 'help' to the bot
#   without any parameters. %s is replaced with Cinch’s current
#   nickname.
#
# == Writing help messages
# In order to add help strings, update your plugins to set +help+
# properly like this:
#
#   class YourPlugin
#     include Cinch::Plugin
#
#     set :help, <<-HELP
#   command <para1> <para2>
#     This command does this and that. The description may
#     as well be multiline.
#   command2 <para1> [optpara]
#     Another sample command.
#     HELP
#   end
#
# Cinch recognises a command in the help string as one if it starts at
# the beginning of the line, all subsequent indented lines are considered
# part of the command explanation, up until the next line that is not
# indented or the end of the string. Multiline explanations are therefore
# handled fine, but you should still try to keep the descriptions as short
# as possible, because many IRC servers will block too much text as flooding,
# resulting in the help messages being cut. Instead, provide a web link or
# something similar for full-blown descriptions.
#
# The command itself may be in any form you want (as long as it’s a single
# line), but I recommend the following conventions so users know how to
# talk to the bot:
#
# [cinch ...]
#   A command Cinch understands when posted publicely into the channel,
#   prefixed with its name (or whatever prefix you want, replace "cinch"
#   accordingly).
# [/msg cinch ...]
#   A command Cinch understands when send directly to him via PM and
#   without a prefix.
# [[/msg] cinch ...]
#   A command Cinch understands when posted publicely with his nick as
#   a prefix, or privately to him without any prefix.
# [...]
#   That is, a bare command without a prefix. Cinch watches the conversion
#   on the channel, and whenever he encounters this string/pattern he will
#   take action, without any prefix at all.
#
# The word "cinch" in the command string will automatically be replaced with
# the actual nickname of your bot.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A help plugin for Cinch.
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

# Help plugin for Cinch.
class Cinch::Help
  include Cinch::Plugin

  listen_to :connect, :method => :on_connect
  match /help(.*)/i, :prefix => lambda{|msg| Regexp.compile("^#{Regexp.escape(msg.bot.nick)}:?\s*")}, :react_on => :channel
  match /help(.*)/i, :use_prefix => false, :react_on => :private

  set :help, <<-EOF
[/msg] cinch help
  Post a short introduction and list available plugins.
[/msg] cinch help <plugin>
  List all commands available in a plugin.
[/msg] cinch help search <query>
  Search all plugin’s commands and list all commands containing
  <query>.
  EOF

  def execute(msg, query)
    query = query.strip.downcase
    response = ""

    # Act depending on the subcommand.
    if query.empty?
      response << @intro_message.strip << "\n"
      response << "Available plugins:\n"
      response << bot.config.plugins.plugins.map{|plugin| format_plugin_name(plugin)}.join(", ")
      response << "\n'help <plugin>' for help on a specific plugin."

    # Help for a specific plugin
    elsif plugin = @help.keys.find{|plugin| format_plugin_name(plugin) == query}
      @help[plugin].keys.sort.each do |command|
        response << format_command(command, @help[plugin][command], plugin)
      end

    # help search <...>
    elsif query =~ /^search (.*)$/i
      query2 = $1.strip
      @help.each_pair do |plugin, hsh|
        hsh.each_pair do |command, explanation|
          response << format_command(command, explanation, plugin) if command.include?(query2)
        end
      end

      # For plugins without help
      response << "Sorry, no help available for the #{format_plugin_name(plugin)} plugin." if response.empty?

    # Something we don't know what do do with
    else
      response << "Sorry, I cannot find '#{query}'."
    end

    response << "Sorry, nothing found." if response.empty?
    msg.reply(response)
  end

  # Called on startup. This method iterates the list of registered plugins
  # and parses all their help messages, collecting them in the @help hash,
  # which has a structure like this:
  #
  #   {Plugin => {"command" => "explanation"}}
  #
  # where +Plugin+ is the plugin’s class object. It also parses configuration
  # options.
  def on_connect(msg)
    @help = {}

    if config[:intro]
      @intro_message = config[:intro] % bot.nick
    else
      @intro_message = "#{bot.nick} at your service."
    end

    bot.config.plugins.plugins.each do |plugin|
      @help[plugin] = Hash.new{|h, k| h[k] = ""}
      next unless plugin.help # Some plugins don't provide help
      current_command = "<unparsable content>" # For not properly formatted help strings

      plugin.help.lines.each do |line|
        if line =~ /^\s+/
          @help[plugin][current_command] << line.strip
        else
          current_command = line.strip.gsub(/cinch/i, bot.name)
        end
      end
    end
  end

  private

  # Format the help for a single command in a nice, unicode mannor.
  def format_command(command, explanation, plugin)
    result = ""

    result << "┌─ " << command << " ─── Plugin: " << format_plugin_name(plugin) << " ─" << "\n"
    result << explanation.lines.map(&:strip).join(" ").chars.each_slice(80).map(&:join).join("\n")
    result << "\n" << "└ ─ ─ ─ ─ ─ ─ ─ ─\n"

    result
  end

  # Downcase the plugin name and clip it to the last component
  # of the namespace, so it can be displayed in a user-friendly
  # way.
  def format_plugin_name(plugin)
    plugin.to_s.split("::").last.downcase
  end

end
