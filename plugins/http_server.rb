# -*- coding: utf-8 -*-
#
# = Cinch HTTP server plugin
# This plugin provides a simple HTTP server inside Cinch,
# allowing him to interact with external services. This
# plugin itself just starts/stops the HTTP server, so you
# want to build your own Cinch plugins on top of it. Just
# extend your own plugin with Cinch::HttpServer::Verbs and
# define your HTTP handlers! (see below for an example)
#
# The general idea is that adding an HTTP route to Cinch’s
# HTTP server shouldn’t be harder than adding listeners
# for events to Cinch. Fortunately, the Sinatra[http://sinatrarb.com]
# library supports a super-easy DSL for defining HTTP routes,
# which is (partly) made available to you in your own Cinch
# plugins when you include the HttpServer::Verbs module.
# To achieve this, HttpServer wraps a super-simple, empty
# Sinatra application to which any calls to the route-defining
# methods are forwarded. As any Sinatra application is also
# a valid Rack end-point, we just pass it into Thin, a very
# capable event-based server for Rack applications that is
# clearly superior to Ruby’s built-in WEBrick.
#
# == Dependencies
# * Sinatra
# * Thin
#
# == Configuration
#
# You can specify the host to bind the HTTP server to and the
# port where you want it to listen. Keep in mind that lower
# ports require root privileges to bind to, which you generally
# don’t want to grant to an IRC bot.
#
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::HttpServer] = {
#     :host => "0.0.0.0",
#     :port => 1234
#   }
#
# [host]
#   The host to bind to. "0.0.0.0" will make your server
#   publicely available, "localhost" restricts to
#   connections from the local machine.
# [port]
#   The port you want the HTTP server to listen at.
#
# == Example
#   class SayHello
#     include Cinch::Plugin
#     extend Cinch::HttpServer::Verbs
#   
#     get "/greet" do
#       bot.channels.each{|channel| channel.send("Hi to everyone!")}
#     end
#   
#   end
#
# The Cinch bot including this plugin will echo "Hi to everyone!"
# to all channels he’s currently in when it receives a GET
# request to the /greet URL.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# An HTTP server plugin for the Cinch IRC bot.
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

require "forwardable"
require "sinatra"
require "thin"

# HTTP Server plugin for Cinch.
class Cinch::HTTPServer

  # Micro Sinatra application that is extended by
  # other Cinch plugins by means of including the
  # Verbs module and defining routes.
  class CinchHttpServer < Sinatra::Base
    set :bind, "0.0.0.0"
    set :port, 1234
  end

  # Extend your plugins with this module to allow them
  # to register routes to the HTTP server. You’ll get
  # direct access to Sinatra’s ::get, ::put, ::post,
  # ::patch, and ::delete methods.
  module Verbs
    extend Forwardable
    delegate [:get, :put, :post, :patch, :delete] => CinchHttpServer
  end

  include Cinch::Plugin
  listen_to :connect,    :method => :start_http_server
  listen_to :disconnect, :method => :stop_http_server

  def start_http_server(msg)
    bot.info "Starting HTTP server"
    @server = Thin::Server.new("0.0.0.0", 1234, CinchHttpServer, signals: false)
    @server.start
  end

  def stop_http_server(msg)
    bot.info "Halting HTTP server"
    @server.stop!
  end

end
