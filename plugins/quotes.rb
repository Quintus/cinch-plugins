# -*- coding: utf-8 -*-
#
# = Cinch Quotes plugin
# This plugin adds a simple quotes system to Cinch.
#
# == Author
# Zach Bloomquist
#
# == License
# A quotes plugin for Cinch.
# Copyright © 2014 Zach Bloomquist
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
class Cinch::Quotes
	include Cinch::Plugin
	require 'net/http'
	match /quote add (.+)$/,         :method => :add
	match /quote$/,                  :method => :random_quote
	match /quote ([0-9]+)$/,         :method => :specific_quote
	match /quote find (.+)$/,        :method => :search
	match /quote list$/,             :method => :list
	listen_to :connect,              :method => :on_connect
	set :help, <<-HELP
cinch quote
	See a random quote from the quotes database.
cinch quote <quote-id>
	View a specific quote by its numerical ID.
cinch quote add <quote>
	Add a quote to the database.
cinch quote find <terms>
	Search the quote database for a quote matching <terms> and return
	a random match.
cinch quote list
	Get a list of all the quotes in the database.
	HELP
	def on_connect(*)
		@db_location = 'data/quotes.txt'
	end
	def add(msg,quote)
		fd = File.open(@db_location,'a')
		fd.puts(quote+"\n")
		fd.close
		lines = File.readlines(@db_location).length-1
		msg.reply('Quote #'+lines.to_s+' added.')
	end
	def random_quote(msg)
		quotes = File.readlines(@db_location)
		msg.reply('There are no quotes defined!') and return unless quotes.length > 0
		quote_id = rand(quotes.length)
		msg.reply('Quote #'+quote_id.to_s+': '+quotes[quote_id])
	end
	def specific_quote(msg,id)
		quotes = File.readlines(@db_location)
		msg.reply('Error 404 Quote Not Found') and return unless quotes[id.to_i]
		msg.reply('Quote #'+id+': '+quotes[id.to_i])
	end
	def search(msg,terms)
		candidates = Hash.new
		fd = File.new(@db_location)
		fd.each { |line| candidates[fd.lineno] = line if line.include? terms }
		msg.reply('No quotes found matching those search terms.') and return if candidates.length == 0
		rand_id = rand(candidates.length)
		msg.reply('Quote #'+(candidates.keys[rand_id]-1).to_s+': '+candidates[candidates.keys[rand_id]])
	end
	def list(msg)
		# POST the entire quote database, formatted, to sprunge.us
		quotes = '================================ Quote Listing ================================'+"\n"
		fd = File.new(@db_location)
		fd.each { |line| quotes << 'Quote #'+fd.lineno.to_s+': '+line if line.strip }
                uri = URI('http://p.chary.us/')
                response = Net::HTTP.post_form(uri,'sprunge' => quotes)
		msg.reply('Quote posting failed.') and return unless response.body
		msg.reply('Quote list: '+response.body)
	end
end
