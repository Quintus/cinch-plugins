# -*- coding: utf-8 -*-
#
# = Cinch Link Info plugin
# Inspects any links that are posted into a channel Cinch
# is currently in and prints out the value of the title
# and description meta tags, if any.
#
# == Dependencies
# * Gem: nokogiri
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::LinkInfo] = {
#     :blacklist => [/\.xz$/],
#     :no_description => false,
#   }
#
# [blacklist]
#   If a URL matches any of the regular expressions defined
#   in this array, it will not be inspected. This plugin
#   alraedy ignores URLs ending in common image file
#   extensions, so you don’t have to specify .png, .jpeg,
#   etc.
# [no_description]
#   Set this to true if you want Cinch to not print the
#   content of the Meta description tag.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A link info plugin for Cinch.
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

require "open-uri"
require "nokogiri"

# Plugin for inspecting links pasted into channels.
class Cinch::LinkInfo
  include Cinch::Plugin

  # Default list of URL regexps to ignore.
  DEFAULT_BLACKLIST = [/\.png$/i, /\.jpe?g$/i, /\.bmp$/i, /\.gif$/i, /\.pdf$/i].freeze

  set :help, <<-HELP
http[s]://...
  I’ll fire a GET request at any link I encounter, parse the HTML
  meta tags, and paste the result back into the channel.
  HELP

  match %r{(https?://.*?)(?:\s|$|,|\.\s|\.$)}, :use_prefix => false

  def execute(msg, url)
    blacklist = DEFAULT_BLACKLIST.dup
    blacklist.concat(config[:blacklist]) if config[:blacklist]

    return if blacklist.any?{|entry| url =~ entry}
    debug "URL matched: #{url}"
    html = Nokogiri::HTML(open(url))

    if node = html.at_xpath("html/head/title")
      msg.reply("Title: #{node.text}")
    end

    if !config[:no_description]
      node = html.at_xpath('html/head/meta[@name="description"]') || html.at_xpath('html/head/meta[@name="Description"]')
      if node
        if node[:content].chars.count > 255
          msg.reply("Description: #{node[:content].lines.first(3).join("").gsub("\n", " ")[0..255] + "..."}")
        else
          msg.reply("Description: #{node[:content]}")
        end
      end
    end
  rescue => e
    error "#{e.class.name}: #{e.message}"
  end

end
