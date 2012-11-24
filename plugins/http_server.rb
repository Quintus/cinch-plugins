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
#     :logfile => "/var/log/cinch-http-server.log" # OPTIONAL
#   }
#
# [host ("localhost")]
#   The host to bind to. "0.0.0.0" will make your server
#   publicely available, "localhost" restricts to
#   connections from the local machine.
# [port (1234)]
#   The port you want the HTTP server to listen at.
# [logfile (:cinch)]
#   If you don’t set this (or set it to the symbol :cinch),
#   the HTTP server will log all requests received onto
#   Cinch’s standard logging facility, which in turn forwards
#   to all loggers registered with the bot instance (see
#   Cinch::Bot#loggers). If you set this to a string, it will
#   be treated as a filename of a log file to open solely
#   for the HTTP requests; the file will be in Apache common
#   log format and nothing else beside the HTTP requests will
#   be logged there.
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
#    to channels and the like. It returns the Cinch::Bot instance
#    currently running.
# 3. The return value of the block determines what is sent back
#    to the requesting client. You shouldn’t use Cinch as a fully-
#    fleged HTTP server, so in most cases you just want to answer
#    with 204 No Content and an empty response (see example above).
#    If you want more, have a look at Sinatra’s excellent README:
#    http://www.sinatrarb.com/intro#Return%20Values
#
# == A note about logging
# Each received HTTP request will be logged via Cinch’s +loggers+
# mechanism by default, no separate log file is created. To get
# a log file, you have two possibilities: The first one is to
# just add a permanent logger to Cinch’s logging mechanism:
#
#   file = open("/var/log/cinch.log", "a")
#   file.sync = true
#   yourbot.loggers.push(Cinch::Logger::FormattedLogger.new(file)
#
# /var/log/cinch.log will contain all of Cinch’s log messages, those
# from the HTTP server included. If you just want to persist the HTTP
# requests received (or want the HTTP requests in a separate log file)
# you can set the configuration option :logfile to an apropriate
# log file path. See the _Configuration_ section above for an example.
# == Author
# Marvin Gülker (Quintus)
#
# == License
# An HTTP server plugin for the Cinch IRC bot.
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

require "forwardable"
require "sinatra"
require "thin"

# HTTP Server plugin for Cinch.
class Cinch::HttpServer

  # Logging adapter between Rack and Cinch. You can pass an instance
  # of this class into Rack::CommonLogger.new and it will make the
  # Rack logger log onto all of Cinch’s registered loggers (at info
  # level).
  class CinchLogging

    # Create a new instance of this class. Pass in the
    # Cinch::Bot instance to log to.
    def initialize(bot)
      @bot = bot
    end

    # This method is called by Rack::CommonLogger when it wants
    # to write out a line. It delegates to the +info+ method of
    # the wrapped bot’s +loggers+ attribute.
    def write(str)
      @bot.loggers.info(str)
    end

  end

  # Micro Sinatra application that is extended by
  # other Cinch plugins by means of including the
  # Verbs module and defining routes.
  class CinchHttpServer < Sinatra::Base

    # When starting the server, we set this to the currently
    # running Cinch::Bot instance.
    def self.bot=(bot)
      @bot = bot
    end

    # The currently running Cinch::Bot instance or +nil+ if
    # it’s not available yet (i.e. the bot hasn’t been started
    # yet).
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
    host    = config[:host]    || "localhost"
    port    = config[:port]    || 1234
    logfile = config[:logfile] || :cinch

    bot.info "Starting HTTP server on #{host} port #{port}"

    # Set up thin with our Rack endpoint
    @server = Thin::Server.new(host,
                               port,
                               CinchHttpServer,
                               signals: false)

    # If requested, iject our special rack-to-cinch logging
    # adapter that makes Rack::CommonLogger log to Cinch’s
    # registered loggers. We cannot add this middleware
    # earlier, because we don’t have the requried Cinch::Bot
    # instance ready prior to calling `start_http_server'.
    if logfile == :cinch
      @server.app.use(Rack::CommonLogger, CinchLogging.new(bot))
    else
      # Otherwise, just create a normal CommonLogger to store
      # our HTTP request log in.
      file = File.open(logfile.to_str, "a")
      file.sync = true # Logs should never be buffered
      @server.app.use(Rack::CommonLogger, file)
    end

    # Make the Cinch::Bot instance available inside the HTTP
    # handlers.
    @server.app.bot = bot

    # Start the HTTP server!
    @server.start
  end

  def stop_http_server(msg)
    bot.info "Halting HTTP server"
    @server.stop!
  end

end
