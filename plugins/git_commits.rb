# coding: utf-8
#
# = Cinch GitCommits plugin
#
# This plugin monitors all Git repositories in a specified directory.
# If it finds new commits, it outputs a notification to all currently
# joined channels. The repositories are checked every 60 seconds.
#
# This plugin is assumed to be run client-side. It does not interact
# with Git's hook system. If you want to print a message via Cinch
# e.g. from a post-receive hook, take a look at the fifo plugin.
#
# == Dependencies
#
# None except Git.
#
# == Configuration
#
# Add the following to your bot’s configure.do stanza:
#
#   config.plugins.options[Cinch::GitCommits] = {
#     :directory  => "/var/git/repos" # required
#   }
#
# [:directory]
#   The directory under which the Git repositories are kept.
#   Git repositories have to end with ".git" to be recognised
#   as Git repositories.
#
# == Author
# Marvin Gülker (Quintus)
#
# A Cinch plugin for infos about new Git commits.
# Copyright © 2019 Marvin Gülker
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
class Cinch::GitCommits
  include Cinch::Plugin

  timer 60, :method => :check_new_commits

  def on_connect(*)
    raise(ArgumentError, "No :directory configured")
  end

  def check_new_commits
    if config[:directory] =~ /\.git$/
      repositories = [config[:directory]]
    else
      repositories = Dir.glob("#{config[:directory]}/*.git")
    end

    @heads ||= {}
    if @heads.empty?
      repositories.each do |repo|
        Dir.chdir(repo) do
          @heads[repo] = `git rev-parse HEAD`.strip
        end
      end
    else
      repositories.each do |repo|
        Dir.chdir(repo) do
          head = `git rev-parse HEAD`.strip
          if @heads[repo] != head
            author, timestamp, subject = `git show -s --format='%an:%at:%s' #{head}`.split(":")
            commits   = `git log --oneline #{@heads[repo]}..#{head}`.lines.count
            timestamp = Time.at(timestamp.to_i)
            reponame  = File.basename(repo).match(/\.git$/).pre_match

            if commits == 1
              bot.channels.each{|c| c.send("[#{reponame}] One new commit")}
            else
              bot.channels.each{|c| c.send("[#{reponame}] #{commits} new commits")}
            end

            bot.channels.each{|c| c.send("[#{reponame}] On #{timestamp.strftime('%Y-%m-%d %H:%M %:z')}, #{author} commited the latest one, #{head[0..6]}: #{subject.lines.first.chomp}")}
            @heads[repo] = head
          end
        end
      end
    end
  end

end
