# coding: utf-8

# This class is able to parse IRC color codes, tokenize them, and convert
# the result array of Token instances into nice HTML markup. Short usage
# is like this:
#
#   converter = MircCodesConverter.new
#   converter.convert("str with IRC color codes") #=> <span>...</span>
#
# You can also split up tokenising and markup conversion:
#
#  converter = MircCodesConverter.new
#  tokens = converter.tokenize("str with IRC color codes")
#  markup = converter.htmlformat(tokens) #=> <span>...</span>
#
# To be clear: This is NOT a plugin. It’s only a helper class.
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A mIRC color codes parser and HTML converter.
# Copyright © 2015 Marvin Gülker
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
class Cinch::MircCodesConverter

  # Maps the mIRC color codes to HTML colors.
  COLORMAP = {"00"=> "white",
              "01" => "black",
              "02"=> "blue",
              "03"=> "green",
              "04"=> "red",
              "05"=> "brown",
              "06" => "purple",
              "07"=> "orange",
              "08"=> "yellow",
              "09"=> "lime",
              "10"=> "teal",
              "11" => "aqua",
              "12"=> "royal",
              "13"=> "pink",
              "14"=> "grey",
              "15"=> "silver"}

  # A single token. Contains the :name of the token, and one
  # or two possible arguments.
  Token = Struct.new(:name, :argument, :argument2)

  # Convenience method for calling #tokenize and #htmlformat
  # subsequently.
  def convert(str)
    htmlformat(tokenize(str))
  end

  # Break up the given string into IRC color code tokens, represented
  # by Token instances in an array.
  def tokenize(str)
    ss = StringScanner.new(str)
    tokens = []

    loop do
      if ss.scan(/\u0003/)
        tokens << Token.new(:color, ss.scan(/\d+/).to_i)

        if bgcolor = ss.scan(/,\d+/)
          tokens.last.argument2 = bgcolor[1..-1].to_i # Skip leading comma
        end
      elsif ss.scan(/\u0002/)
        tokens << Token.new(:bold)
      elsif ss.scan(/\u001F/)
        tokens << Token.new(:underline)
      elsif ss.scan(/\u0016/)
        tokens << Token.new(:reverse)
      elsif ss.scan(/\u001D/)
        tokens << Token.new(:italic)
      elsif ss.scan(/\u000F/)
        tokens << Token.new(:reset)
      else
        tokens << Token.new(:plain, ss.getch)
      end
      break if ss.eos?
    end

    tokens
  end

  # Take a Token instance array as returned by #tokenize and convert it
  # to HTML markup. Returned is a string containing only inline elements,
  # so you need to add surrounding <p></p> or other tags yourself.
  def htmlformat(tokens)
    result = ""
    stack = []
    tokens.each do |token|
      case token.name
      when :color then
        result << "<span style='color: #{COLORMAP[sprintf('%02d', token.argument)]}"

        if token.argument2
          result << "; background-color: #{COLORMAP[sprintf('%02d', token.argument2)]}"
        end

        result << "'>"
        stack.push("</span>")
      when :bold then
        result << "<strong>"
        stack.push("</strong>")
      when :underline then
        result << "<span style='text-decoration: underline'>"
        stack.push("</span>")
      when :reverse then
        # TODO
      when :italic then
        result << "<em>"
        stack.push("</em>")
      when :reset then
        result << stack.pop until stack.empty?
      when :plain then
        result << token.argument
      else
        $stderr.puts "Invalid token type: '#{token.name}'"
      end
    end

    result
  end

end
