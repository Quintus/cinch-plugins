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
# It is not required to restart the bot in order to regonise new
# repositories; they will be picked up on the next scan automatically.
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
    raise(ArgumentError, "No :directory configured") unless config[:directory]
  end

  def check_new_commits
    if config[:directory] =~ /\.git$/
      repositories = [config[:directory]]
    else
      repositories = Dir.glob("#{config[:directory]}/*.git")
    end

    @repos ||= {}
    if @repos.empty?
      repositories.each do |repo|
        @repos[repo] = read_heads(repo)
      end
    else
      # Handle deleted repositories
      deleted_repositories = @repos.keys - repositories
      deleted_repositories.sort.each do |repo|
        reponame = File.basename(repo).match(/\.git$/).pre_match
        bot.channels.each{|c| c.send("Deleted Git Repository: #{reponame}")}
        @repos.delete(repo)
      end

      repositories.each do |repo|
        reponame  = File.basename(repo).match(/\.git$/).pre_match
        new_heads = read_heads(repo)

        # Handle new repository
        unless @repos.has_key?(repo)
          bot.channels.each{|c| c.send("New Git Repository: #{reponame}")}
          @repos[repo] = {}
        end

        # Handle deleted branches
        deleted_branches = @repos[repo].keys - new_heads.keys
        deleted_branches.sort.each do |branch|
          bot.channels.each{|c| c.send("[#{reponame}] Deleted branch: #{branch}")}
          @repos[repo].delete(branch)
        end

        new_heads.each_pair do |branch, hash|
          author, timestamp, subject = `git -C "#{repo}" show -s --format='%an:%at:%s' #{hash}`.split(":")
          timestamp = Time.at(timestamp.to_i)

          if @repos[repo].has_key?(branch)
            if @repos[repo][branch] == hash # equal hashes = nothing changed
              next
            else # changed hash = new commits
              commits = `git -C "#{repo}" log --oneline #{@repos[repo][branch]}..#{hash}`.lines.count

              if commits == 1
                bot.channels.each{|c| c.send("[#{reponame}: #{branch}] One new commit")}
              else
                bot.channels.each{|c| c.send("[#{reponame}: #{branch}] #{commits} new commits")}
              end
            end
          else # Handle new branch
            bot.channels.each{|c| c.send("[#{reponame}] New branch: #{branch}")}
          end

          bot.channels.each{|c| c.send("[#{reponame}: #{branch}] On #{timestamp.strftime('%Y-%m-%d %H:%M %:z')}, #{author} commited the latest one, #{hash[0..6]}: #{subject.lines.first.chomp}")}
          @repos[repo] = new_heads
        end
      end
    end
  end

  private

  def read_heads(repo)
    heads = {}
    IO.popen(["git", "-C", repo, "for-each-ref", "--sort=-committerdate", "refs/heads"]) do |io|
      while line = io.gets
        ary = line.split(/\s+/)
        name = ary[2].match(%r<^refs/heads/>).post_match
        heads[name] = ary[0]
      end
    end
    if (exitstatus = $?.exitstatus) != 0 # Single = intended
      bot.loggers.warn("Retrieving heads failed for repository #{repo}. Git exitstatus: #{exitstatus}")
    end

    heads
  end

end
