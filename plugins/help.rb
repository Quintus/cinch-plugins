# -*- coding: utf-8 -*-
class Cinch::Help
  include Cinch::Plugin
  extend Cinch::Self

  listen_to :connect, :method => :parse_help
  listen_for /help(.*)/i

  set :help, <<-EOF
help
  List all available plugins.
help <plugin>
  List all commands available in a plugin.
help search <query>
  Search all plugin’s commands and list all commands containing
  <query>.
  EOF

  def execute(msg, query)
    query = query.strip.downcase
    response = ""

    if query.empty?
      response << "Available plugins:\n"
      response << bot.config.plugins.plugins.map{|plugin| format_plugin_name(plugin)}.join(", ")
      response << "\n'help <plugin>' for help on a specific plugin."
    elsif plugin = @help.keys.find{|plugin| format_plugin_name(plugin) == query}
      @help[plugin].keys.sort.each do |command|
        response << format_command(command, @help[plugin][command], plugin)
      end
    elsif query =~ /^search (.*)$/i
      query2 = $1.strip
      @help.each_pair do |plugin, hsh|
        hsh.each_pair do |command, explanation|
          response << format_command(command, explanation, plugin) if command.include?(query2)
        end
      end

      # For plugins without help
      response << "Sorry, no help available for the #{format_plugin_name(plugin)} plugin." if response.empty?
    else
      response << "Sorry, I cannot find '#{query}'."
    end

    response << "Sorry, nothing found." if response.empty?
    msg.reply(response)
  end

  def parse_help(msg)
    @help = {}

    bot.config.plugins.plugins.each do |plugin|
      @help[plugin] = Hash.new{|h, k| h[k] = ""}
      next unless plugin.help # Some plugins don't provide help
      current_command = "<unparsable content>" # For not properly formatted help strings

      plugin.help.lines.each do |line|
        if line =~ /^\s+/
          @help[plugin][current_command] << line.strip
        else
          current_command = line.strip
        end
      end
    end
  end

  private

  # Format the help for a single command in a nice, unicode mannor.
  def format_command(command, explanation, plugin)
    result = ""

    result << "┌" << "── " << command << " ─── Plugin: " << format_plugin_name(plugin) << " ─" << "\n│"
    result << explanation.lines.map(&:strip).join(" ").chars.each_slice(80).map(&:join).join("\n│").chop
    result << "\n" << "└" << "\n"

    result
  end

  def format_plugin_name(plugin)
    plugin.to_s.split("::").last.downcase
  end

end
