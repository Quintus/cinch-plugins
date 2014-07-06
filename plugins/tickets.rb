# -*- coding: utf-8 -*-
#
# = Cinch Ticket plugin
# Looks for # in the channel and makes a link
# to your issue tracker from it.
#
# == Dependencies
# * Gem: nokogiri
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::Tickets] = {
#     :url => "http://example.org/tickets/%d
#   }
#
# [url]
#   The base URL for tickets. %d gets replaced with the
#   number encountered after the hash sign #.
#   If you need a raw % sign in your URL, use %%.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A ticket link plugin for Cinch.
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

require "open-uri"
require "nokogiri"

class Cinch::Tickets
  include Cinch::Plugin

  set :help, <<-HELP
#<ticket id>
  I will automatically post a link to the corresponding issue
  ticket and print the title tag.
  HELP

  match %r{#(\d+)}, :use_prefix => false

  def execute(msg, id)
    return if msg.user == bot

    url = sprintf(config[:url], id.to_i)
    debug "Issue ticket matched: #{id}: #{url}"

    msg.reply("Ticket ##{id} is at: #{url}")
    html = Nokogiri::HTML(open(url))

    if node = html.at_xpath("html/head/title")
      msg.reply("Title: #{node.text}")
    end
  end

end
