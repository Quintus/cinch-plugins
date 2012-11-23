# -*- coding: utf-8 -*-
#
# = Cinch Echo plugin
# Assuming your bot is named mega-cinch:
#   <me> mega-cinch: echo Hi there!
#   <mega-cinch> Hi there!
# You see what it does, don’t you?
#
# == Configuration
# None.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# An echo plugin for Cinch.
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

require_relative "self"

class Cinch::Echo
  include Cinch::Plugin
  extend Cinch::Self

  recognize /echo (.*)/

  def execute(msg, text)
    msg.reply(text)
  end

end
