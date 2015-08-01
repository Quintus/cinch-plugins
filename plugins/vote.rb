# -*- coding: utf-8 -*-
#
# = Cinch Voting plugin
# This is a voting plugin for more serious use. It allows
# a specified number of nicks to vote exactly once on a
# given topic, optionally requiring them to be authenticated
# against NickServ in order to be able to vote.
# Multiple votes are supported in parallel, and each vote
# may either be public or covert, where in the latter case
# nobody will be able to see who voted on which option (as
# voting occurs via PM to the bot), but only see the results.
#
# == Dependencies
# None.
#
# == Configuration
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::Vote] = {
#     :auth_required => true,
#     :voters => %w[Carlo, n0b0dY]
#   }
#
# [auth_required]
#   If true, the voters must be authenticated against
#   NickServ to be able to exercise their voting right.
#   This is recommended to turn on, because otherwise
#   a simple /nick command is enough to impersonate
#   someone seemingly known just for voting manipulation.
# [voters]
#   List of nicks (array of strings) that are allowed to
#   vote. Before adding to this list, you have to check
#   that the person using this nick is actually the person
#   you think it is.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# Voting plugin for Cinch.
# Copyright © 2015 Marvin Gülker
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

require "time"

class Cinch::Vote
  include Cinch::Plugin

  Vote = Struct.new(:topic, :choices, :covert, :end_time, :running, :voters, :results, :thread, :channel) do
    def initialize(*)
      super
      self.choices = []
      self.covert  = false
      self.running = false
      self.voters  = []
      self.results = Hash.new(0)
      self.end_time = Time.at(0)
    end
  end

  match /vote create (.*)$/,      :method => :on_create, :react_on => :channel
  match /vote set covert (\d+)$/, :method => :on_set_covert, :react_on => :channel
  match /vote set public (\d+)$/, :method => :on_set_public, :react_on => :channel
  match /vote add-choice (\d+) (.*)$/,  :method => :on_add_choice, :react_on => :channel
  match /vote del-choice (\d+) (\d+)$/, :method => :on_del_choice, :react_on => :channel
  match /vote set-end (\d+) (.*)$/,     :method => :on_end,  :react_on => :channel
  match /vote start (\d+)$/,            :method => :on_start, :react_on => :channel
  match /vote list$/,                   :method => :on_list, :react_on => :message
  match /vote show (\d+)$/,             :method => :on_show, :react_on => :message
  match /vote on (\d+) (\d+)$/,         :method => :on_public_vote, :react_on => :message
  match /vote on (\d+) (\d+)$/,         :method => :on_private_vote, :react_on => :private
  match /vote delete (\d+)$/,           :method => :on_delete, :react_on => :channel

  private

  def on_create(msg, topic)
    @votes ||= []
    @votes << Vote.new(topic)

    config[:voters].each do |nick|
      user = User(nick) # nil if not found
      @votes.last.voters << user if user && (!config[:auth_required] || user.authed?)
    end

    @votes.last.channel = msg.channel
    msg.reply("Created new vote with ID #{@votes.count}.")
  end

  def on_set_covert(msg, id)
    return unless check_perms(msg, id)

    @votes[id.to_i - 1].covert = true
    msg.reply("Vote is now covert. Vote by using /query #{bot.nick} vote <id> <num>.")
  end

  def on_set_public(msg, id)
    return unless check_perms(msg, id)

    @votes[id.to_i - 1].covert = false
    msg.reply("Vote is now public. Vote by using #{Cinch::Vote.prefix}vote <id> <num>.")
  end

  def on_add_choice(msg, id, choice)
    return unless check_perms(msg, id)

    vote = @votes[id.to_i - 1]
    vote.choices << choice

    msg.reply("Choice added.")
  end

  def on_del_choice(msg, id, num)
    return unless check_perms(msg, id)

    result = @votes[id.to_i - 1].choices.slice!(num.to_i - 1)

    if result
      msg.reply("Choice deleted.")
    else
      msg.reply("No such choice.")
    end
  end

  def on_end(msg, id, timestr)
    return unless check_perms(msg, id)

    time = Time.parse(timestr)
    @votes[id.to_i - 1].end_time = time

    msg.reply("Voting period ends on #{time}.")
  end

  def on_start(msg, id)
    return unless check_perms(msg, id)

    vote = @votes[id.to_i - 1]

    if vote.running
      msg.reply("This vote is running already.")
      return
    end

    vote.running = true
    vote.thread  = Thread.new do
      loop do
        sleep(60)
        break if Time.now >= vote.end_time
      end

      vote.running = false
      msg.reply(Format(:red, :bold, "The voting period for vote “#{vote.topic}” has ended. Use #{Cinch::Vote.prefix}vote show <id> to see the results."))
    end

    msg.reply("Voting has started. The voting period ends on #{Format(:bold, vote.end_time.to_s)}.")
  end

  def on_list(msg)
    @votes ||= []

    if @votes.empty?
      msg.reply("No votes available.")
    else
      msg.reply("The following votes exist: ")
      @votes.each_with_index do |vote, index|
        msg.reply(Format(:bold, "#{index + 1}.") + " " + vote.topic)
      end
    end
  end

  def on_show(msg, id)
    msg.reply("No such vote.") and return false unless @votes[id.to_i - 1]

    vote = @votes[id.to_i - 1]
    msg.reply("Vote: #{Format(:bold, :cyan, vote.topic)}")

    msg.reply("This vote is #{Format(:bold, :yellow, vote.running ? 'running' : 'not running')}.")
    msg.reply("Voting period ends on #{Format(:bold, :yellow, vote.end_time.to_s)}.")

    if vote.choices.empty?
      msg.reply("There are no choices configured for this vote.")
    else
      msg.reply("Choices with results:")
      total_votes = vote.results.values.reduce(0){|sum, val| sum + val}
      charcount   = vote.choices.max_by{|c| c.length}.length

      vote.choices.each_with_index do |choice, index|
        votecount = vote.results[index + 1]
        percent   = ((votecount.to_f / total_votes.to_f) * 100).round(2)

        msg.reply(Format(:bold, "#{index + 1}. ") + sprintf("%-#{charcount}s", choice) + " [" + Format(:bold, :blue, "#{votecount} votes") + ", " + Format(:bold, :green, "#{percent}%") + "]")
      end
    end
  end

  def on_public_vote(msg, id, choicenum)
    vote = @votes[id.to_i - 1]

    msg.reply("No such vote.")                and return unless vote
    msg.reply("No such choice.")              and return unless vote.choices[choicenum.to_i - 1]
    msg.reply("This vote is not running.")    and return unless vote.running
    msg.reply("Voting period is over.")       and return unless Time.now <= vote.end_time
    msg.reply("Not an open vote.")            and return unless !vote.covert
    msg.reply("You are not allowed to vote.") and return unless check_vote_access!(vote, msg.user)

    vote.results[choicenum.to_i] += 1

    msg.reply("Vote registered.")

    check_all_voted(vote)
  end

  def on_private_vote(msg, id, choicenum)
    vote = @votes[id.to_i - 1]

    msg.reply("No such vote.")                and return unless vote
    msg.reply("No such choice.")              and return unless vote.choices[choicenum.to_i - 1]
    msg.reply("This vote is not running.")    and return unless vote.running
    msg.reply("Voting period is over.")       and return unless Time.now <= vote.end_time
    msg.reply("Not a covert vote.")           and return unless vote.covert
    msg.reply("You are not allowed to vote.") and return unless check_vote_access!(vote, msg.user)

    vote.results[choicenum.to_i] += 1

    msg.reply("Vote registered.")

    check_all_voted(vote)
  end

  def on_delete(msg, id)
    check_perms(msg, id)

    vote = @votes.slice!(id.to_i - 1)
    vote.thread.terminate if vote.thread

    msg.reply("Vote deleted.")
  end

  def check_perms(msg, id)
    msg.reply("No such vote.")             and return false unless @votes[id.to_i - 1]
    msg.reply("Only ops can demand this.") and return false unless msg.channel.opped?(msg.user)

    true
  end

  # Returns true if the given user is allowed to vote for this vote.
  # Removes his voting permission in that case, so that a subsequent
  # call for this vote will return false.
  def check_vote_access!(vote, user)
    vote.voters.delete(user.nick)
  end

  # Checks if all people who were allowed to vote have voted,
  # and if so, immediately ends the vote.
  def check_all_voted(vote)
    if vote.voters.empty? && vote.running
      vote.thread.terminate
      vote.running = false
      vote.channel.send(Format(:bold, :red, "All people allowed to vote have voted. The vote is thus ended now. Use `#{Cinch::Vote.prefix}vote show <num>' to see the results."))
    end
  end

end
