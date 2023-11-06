# frozen_string_literal: true

# Retrieves version information from Capistrano's files. The general approach is
# to read the version information (branch name, git SHA, and date deployed) out
# of Capistrano's revisions.log file.
#
# The code is a bit more complicated than it should because Capistrano does not
# always update the revision.log file before the application reads this information.
# Therefore there is logic in this class to detect if the version information is
# stale and re-read it until it is up to date. Because re-reading this file is
# an expensive operation we cache the information as soon as we are sure it's
# current.
#
# rubocop:disable Style/ClassVars
class VersionFooter
  @@stale = true
  @@git_sha = nil
  @@branch = nil
  @@version = nil

  # Returns a hash with version information.
  def self.info
    reset! if stale?
    { sha: git_sha, branch:, version:, stale: stale?, tagged_release: tagged_release? }
  rescue StandardError => ex
    { error: "Error retrieving version information: #{ex.message}" }
  end

  def self.reset!
    # Initalize these values so that they recalculated
    @@git_sha = nil
    @@branch = nil
    @@version = nil
  end

  def self.stale?
    return false if @@stale == false
    # Only read the file when version information is stale
    if File.exist?(revision_file)
      local_sha = File.read(revision_file).chomp.gsub(/\)$/, "")
      @@stale = local_sha != git_sha
    else
      @@stale = true
    end
  end

  def self.git_sha
    @@git_sha ||= if File.exist?(revisions_logfile)
                    log_line(revisions_logfile).chomp.split(" ")[3].gsub(/\)$/, "")
                  elsif Rails.env.development? || Rails.env.test?
                    `git rev-parse HEAD`.chomp
                  else
                    "Unknown SHA"
                  end
  end

  def self.tagged_release?
    # e.g. v0.8.0
    branch.match(/^v[\d+\.+]+/) != nil
  end

  def self.branch
    @@branch ||= if File.exist?(revisions_logfile)
                   log_line(revisions_logfile).chomp.split(" ")[1]
                 elsif Rails.env.development? || Rails.env.test?
                   `git rev-parse --abbrev-ref HEAD`.chomp
                 else
                   "Unknown branch"
                 end
  end

  def self.version
    @@version ||= if File.exist?(revisions_logfile)
                    deployed = log_line(revisions_logfile).chomp.split(" ")[7]
                    Date.parse(deployed).strftime("%d %B %Y")
                  else
                    "Not in deployed environment"
                  end
  end

  # This file is local to the application.
  # This file only has the git SHA of the version deployed (i.e. no date or branch)
  def self.revision_file
    @@revision_file ||= Rails.root.join("REVISION")
  end

  # Capistrano keeps this file a couple of levels up _outside_ the application.
  # This file includes all the information that we need (git SHA, branch name, date)
  def self.revisions_logfile
    @@revisions_logfile ||= Rails.root.join("..", "..", "revisions.log")
  end

  # These assignment methods are needed to facilitate testing
  def self.revision_file=(x)
    @@stale = true
    @@revision_file = x
  end

  def self.revisions_logfile=(x)
    @@stale = true
    @@revisions_logfile = x
  end

  def self.log_line(revisions_logfile)
    log_line = `tail -1 #{revisions_logfile}`
    if log_line.include?("rolled back")
      grep_lines = `grep #{log_line.chomp.split(" ").last} #{revisions_logfile}`.split("\n")
      log_line = grep_lines.first
    end
    log_line
  end
end
# rubocop:enable RuboCop::Cop::Style::ClassVars
