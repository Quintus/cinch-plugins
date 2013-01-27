# -*- coding: utf-8 -*-
class Cinch::Vote
  include Cinch::Plugin

  Vote = Struct.new(:topic, :choices, :open) do
    def initialize(*)
      super
      self.choices = []
      self.open = false
    end
  end

  listen_to :connect, :method => :on_connect
  match /vote create (.*)/, :method => :on_vote_create
  match /vote delete #(\d+)/, :method => :on_vote_delete
  match /vote add-choice #(\d+) (.*)/, :method => :on_vote_add_choice
  match /vote open #(\d+)/, :method => :on_vote_open
  match /vote list/, :method => :on_vote_list
  match /vote show #(\d+)/, :method => :on_vote_show

  def on_connect(*)
    @votes = {}
  end

  def on_vote_create(msg, topic)
    id = generate_vote_id
    @votes[id] = Vote.new(topic)

    msg.reply("Created vote ##{id}.")
  end

  def on_vote_delete(msg, id)
    msg.reply("No vote with id ##{id}.") and return unless @votes[id.to_i]

    @votes.delete(id.to_i)
    msg.reply("Deleted vote ##{id}.")
  end

  def on_vote_add_choice(msg, id, choice)
    msg.reply("No vote with id ##{id}.") and return unless @votes[id.to_i]

    @votes[id.to_i].choices << choice
    msg.reply("Added answer.")
  end

  def on_vote_open(msg, id)
    msg.reply("No vote with id ##{id}.") and return unless @votes[id.to_i]

    @votes[id.to_i].open = true
    msg.reply("Marked vote ##{id} as ready. You can now start voting on it.")
  end

  def on_vote_list(msg)
    msg.reply("There are no votes currently.") and return if @votes.empty?

    msg.reply("The following votes are available (use `vote show #<num>' for details on a vote):")
    @votes.keys.sort.each do |id|
      vote = @votes[id]
      msg.reply("* ##{id}: #{vote.topic} [#{vote.open ? 'open' : 'closed'}]")
    end
  end

  def on_vote_show(msg, id)
    msg.reply("No vote with id ##{id}.") and return unless @votes[id.to_i]

    vote = @votes[id.to_i]
    msg.reply("The topic for vote ##{id} is: \"#{vote.topic}\"")
    msg.reply("This vote is #{vote.open ? 'open' : 'closed'}.")

    msg.reply("Choices:")
    vote.choices.each_with_index do |choice, index|
      msg.reply("* #{index + 1}: #{choice}")
    end
  end

  private

  # Generates a new vote ID.
  def generate_vote_id
    @last_vote_id ||= 0
    @last_vote_id  += 1
  end

end
