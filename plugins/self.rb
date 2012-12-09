# -*- coding: utf-8 -*-
#
# = Cinch’s self
# This is not really a plugin, but merely a helper module to
# make matching messages targetted solely at the bot easier.
# You can +extend+ your plugin with this module and get a
# new method named +recognize+ that behaves exactly like
# Cinch’s own +match+ method except that it automatically
# adds a :prefix consisting of Cinch’s current nickname
# followed by a colon, so that only messages beginning
# with the bot’s current nickname will be recognised by
# this directive.
#
# == License
# This module’s code is heavily inspired by the lambdas example
# in Cinch’s example directory, so I don’t want to relicense code
# from the Cinch project under the LGPL. This isn’t nice, so
# in contrast to most of the other software in this repo, this
# module isn’t LGPL-licensed but is licensed under the 2-clause BSDL.
#
# Copyright © Marvin Gülker
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 
#  *  Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
# 
#  *  Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# === Cinch license
# Copyright (c) 2010 Lee Jarvis, Dominik Honnef
# Copyright (c) 2011 Dominik Honnef
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
module Cinch::Self

  # Like ::match, but always sets :prefix to the bot’s current
  # name. All other options are the same as for +match+.
  def recognize(regexp, hsh = {})
    hsh[:prefix] = lambda{|msg| Regexp.compile("^#{msg.bot.nick}:\s*")}
    match(regexp, hsh)
  end

  # Like ::match, but listens for both private and public messages. For public channel
  # messages, the prefix is set to the bot’s current nickname, for private messages,
  # the prefix is disabled completely. All other options are the same as for +match+.
  def listen_for(regexp, hsh = {})
    match(regexp, hsh.merge(:prefix => lambda{|msg| Regexp.compile("^#{msg.bot.nick}:\s*")}, :react_on => :channel))
    match(regexp, hsh.merge(:use_prefix => false, :react_on => :private))
  end

end
