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
# Gems:
# * thin
# * sinatra
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
#     # Define the route /greet for HTTP GET requests (this
#     # is what your browser fires normally).
#     get "/greet" do
#       # Print a message into all joined IRC channels
#       bot.channels.each{|channel| channel.send("Hi to everyone!")}
#
#       # HTTP statuscode
#       204 # No Content
#     end
#   
#   end
#
# The Cinch bot including this plugin will echo "Hi to everyone!"
# to all channels he’s currently in when it receives a GET
# request to the /greet URL. Note there’s one caveat: Inside the
# HTTP verb methods, i.e. +get+, +post+, etc. you’re not running
# in the normal class context. Instead, +self+ is set to the context
# of the underlying Sinatra::Base subclass Cinch::HttpServer::CinchHttpServer.
# This has three important aspects to note:
#
# 1. You cannot call methods defined inside *your* class.
# 2. To interact with Cinch, call the CinchHttpServer#bot helper
#    method, which _is_ available and allows you to send stuff
#    to channels and the like.
# 3. The return value of the block determines what is sent back
#    to the requesting client. You shouldn’t use Cinch as a fully-
#    fleged HTTP server, so in most cases you just want to answer
#    with 204 No Content and an empty response (see example above).
#    If you want more, have a look at Sinatra’s excellent README:
#    http://www.sinatrarb.com/intro#Return%20Values
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
class Cinch::HttpServer

  # Micro Sinatra application that is extended by
  # other Cinch plugins by means of including the
  # Verbs module and defining routes.
  class CinchHttpServer < Sinatra::Base
    enable :logging

    # When starting the server, we set this to the currently
    # running Cinch::Bot instance.
    def self.bot=(bot)
      @bot = bot
    end

    # The currently running Cinch::Bot instance or +nil+ if
    # it’s not available yet.
    def self.bot
      @bot
    end

    # Shortcut for calling:
    #   self.class.bot
    def bot
      self.class.bot
    end

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
    host = config[:host] || "localhost"
    port = config[:port] || 1234

    bot.info "Starting HTTP server on #{host} port #{port}"
    @server = Thin::Server.new(host,
                               port,
                               CinchHttpServer,
                               signals: false)
    @server.app.bot = bot
    @server.start
  end

  def stop_http_server(msg)
    bot.info "Halting HTTP server"
    @server.stop!
  end

end
