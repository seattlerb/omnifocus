require 'rubygems'
require 'mechanize'
require 'appscript'

##
# Synchronizes bug tracking systems to omnifocus.

class OmniFocus
  VERSION = '1.0.0'

  # bug_db = {
  #   project => {
  #     rf_id => [task_name, url], # only on BTS     = add to OF
  #     rf_id => true,             # both BTS and OF = don't touch
  #     rf_id => false,            # only on OF      = remove from OF
  #   }
  # }

  attr_reader :bug_db

  # existing = {
  #   rf_id => project,
  # }

  attr_reader :existing

  ##
  # Load any file matching "omnifocus/*.rb"

  def self.load_plugins
    Gem.find_files("omnifocus/*.rb").each do |path|
      require path
    end
  end

  ##
  # Load plugins and then execute the script

  def self.run
    load_plugins
    self.new.run
  end

  def initialize
    @bug_db   = Hash.new { |h,k| h[k] = {} }
    @existing = {}
  end

  def its # :nodoc:
    Appscript.its
  end

  ##
  # Get all projects under the nerd folder

  def nerd_projects
    unless defined? @nerd_projects then
      omnifocus      = Appscript.app('OmniFocus').documents[1]
      @nerd_projects = omnifocus.sections[its.name.eq("nerd")].first
    end

    @nerd_projects
  end

  ##
  # Walk all omnifocus tasks under the nerd folder and add them to the
  # bug_db hash if they have [A-Z]+#\d+ in the subject.

  def prepopulate_existing_tasks
    of_tasks = nerd_projects.projects.tasks[its.name.contains("#")].get.flatten
    of_tasks.each do |of_task|
      ticket_id                  = of_task.name.get[/^[A-Z]+#(\d+)/, 1].to_i
      project                    = of_task.containing_project.name.get
      existing[ticket_id]        = project
      bug_db[project][ticket_id] = false
    end
  end

  ##
  # Returns the mechanize agent

  def mechanize
    @mechanize ||= WWW::Mechanize.new
  end

  ##
  # Create any projects in bug_db that aren't in omnifocus, add under
  # the nerd folder.

  def create_missing_projects
    (bug_db.keys - nerd_projects.projects.name.get).each do |name|
      nerd_projects.make :new => :project, :with_properties => { :name => name }
    end
  end

  ##
  # Synchronize the contents of bug_db with omnifocus, creating
  # missing tasks and marking tasks completed as needed. See the doco
  # for +bug_db+ for more info on how you should populate it.

  def update_tasks
    bug_db.each do |name, tickets|
      project = nerd_projects.projects[its.name.eq(name)].projects[1]

      tickets.each do |bts_id, value|
        case value
        when true
          # leave alone
        when false
          project.tasks[its.name.contains("##{bts_id}")].get.each do |task|
            next if task.completed.get
            puts "Removing #{name} # #{bts_id}"
            task.completed.set true
          end
        when Array
          puts "Adding #{name} # #{bts_id}"
          title, url = *value
          project.make(:new => :task,
                       :with_properties => {
                         :note => url,
                         :name => title,
                       })
        else
          abort "ERROR: Unknown value in bug_db #{bts_id}: #{value.inspect}"
        end
      end
    end
  end

  ##
  # Return all the plugin modules that have been loaded.

  def self.plugins
    constants.reject { |mod| mod =~ /^[A-Z_]+$/ }.map { |mod| const_get mod }
  end

  def run
    prepopulate_existing_tasks

    self.class.plugins.each do |plugin|
      extend plugin
      name = plugin.name.split(/::/).last.downcase
      send "populate_#{name}_tasks"
    end

    if $DEBUG then
      require 'pp'
      pp bug_db
    else
      create_missing_projects
      update_tasks
    end
  end
end
