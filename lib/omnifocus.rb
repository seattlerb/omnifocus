require 'rubygems'
require 'appscript'

class Appscript::Reference # :nodoc:
  # HACK: There is apparently a bug in ruby 1.9 where if you have
  # method_missing defined and do some action that calls to_ary, then
  # to_ary will be called on your instance REGARDLESS of whether
  # respond_to_(:to_ary) returns true or not.
  #
  # http://tenderlovemaking.com/2011/06/28/til-its-ok-to-return-nil-from-to_ary/

  def to_ary # :nodoc:
    nil
  end
end if RUBY_VERSION >= "1.9"

##
# Synchronizes bug tracking systems to omnifocus.
#
# Some definitions:
#
# bts: bug tracking system
# SYSTEM: a tag uniquely identifying the bts
# bts_id: a string uniquely identifying a task: SYSTEM(-projectname)?#id

class OmniFocus
  VERSION = '1.5.0'

  ##
  # bug_db = {
  #   project => {
  #     bts_id => [task_name, url], # only on BTS     = add to OF
  #     bts_id => true,             # both BTS and OF = don't touch
  #     bts_id => false,            # only on OF      = remove from OF
  #   }
  # }

  attr_reader :bug_db

  ##
  # existing = {
  #   bts_id => project,
  # }

  attr_reader :existing

  ##
  # Load any file matching "omnifocus/*.rb"

  def self.load_plugins
    filter = ARGV.shift
    loaded = {}
    Gem.find_files("omnifocus/*.rb").each do |path|
      name = File.basename path
      next if loaded[name]
      next unless path.index filter if filter
      require path
      loaded[name] = true
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

  def omnifocus
    unless defined? @omnifocus then
      @omnifocus = Appscript.app('OmniFocus').default_document
    end
    @omnifocus
  end

  def all_tasks
    omnifocus.flattened_projects[its.status.eq(:active)].tasks.get.flatten
  end

  ##
  # Utility shortcut to make a new thing with a name via appscript.

  def make target, type, name, extra = {}
    target.make :new => type, :with_properties => { :name => name }.merge(extra)
  end

  ##
  # Get all projects under the nerd folder

  def nerd_projects
    unless defined? @nerd_projects then
      @nerd_projects = omnifocus.folders["nerd"]

      begin
        @nerd_projects.get
      rescue
        make omnifocus, :folder, "nerd"
      end
    end

    @nerd_projects
  end

  ##
  # Walk all omnifocus tasks under the nerd folder and add them to the
  # bug_db hash if they match a bts_id.

  def prepopulate_existing_tasks
    prefixen = self.class.plugins.map { |klass| klass::PREFIX rescue nil }
    of_tasks = nil

    if prefixen.all? then
      of_tasks = all_tasks.find_all { |task|
        task.name.get =~ /^(#{Regexp.union prefixen}(?:-[\w.-]+)?\#\d+)/
      }
    else
      warn "WA"+"RN: Older plugins installed. Falling back to The Old Ways"

      of_tasks = all_tasks.find_all { |task|
        task.name.get =~ /^([A-Z]+(?:-[\w-]+)?\#\d+)/
      }
    end

    of_tasks.each do |of_task|
      ticket_id = of_task.name.get[/^([A-Z]+(?:-[\w-]+)?\#\d+)/, 1]
      project                    = of_task.containing_project.name.get
      existing[ticket_id]        = project
      bug_db[project][ticket_id] = false
    end
  end

  ##
  # Returns the mechanize agent

  def mechanize
    require 'mechanize'
    @mechanize ||= Mechanize.new
  end

  ##
  # Create any projects in bug_db that aren't in omnifocus, add under
  # the nerd folder.

  def create_missing_projects
    (bug_db.keys - nerd_projects.projects.name.get).each do |name|
      warn "creating project #{name}"
      next if $DEBUG
      make nerd_projects, :project, name
    end
  end

  ##
  # Synchronize the contents of bug_db with omnifocus, creating
  # missing tasks and marking tasks completed as needed. See the doco
  # for +bug_db+ for more info on how you should populate it.

  def update_tasks
    bug_db.each do |name, tickets|
      project = nerd_projects.projects[name]

      tickets.each do |bts_id, value|
        case value
        when true
          project.tasks[its.name.contains(bts_id)].get.each do |task|
            if task.completed.get
              puts "Re-opening #{name} # #{bts_id}"
              next if $DEBUG
              task.completed.set false
            end
          end
        when false
          project.tasks[its.name.contains(bts_id)].get.each do |task|
            next if task.completed.get
            puts "Removing #{name} # #{bts_id}"
            next if $DEBUG
            task.completed.set true
          end
        when Array
          puts "Adding #{name} # #{bts_id}"
          next if $DEBUG
          title, url = *value
          make project, :task, title, :note => url
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
    # do this all up front so we can REALLY fuck shit up with plugins
    self.class.plugins.each do |plugin|
      extend plugin
    end

    prepopulate_existing_tasks

    self.class.plugins.each do |plugin|
      name = plugin.name.split(/::/).last.downcase
      warn "scanning #{name}"
      send "populate_#{name}_tasks"
    end

    if $DEBUG then
      require 'pp'
      pp existing
      pp bug_db
    end

    create_missing_projects
    update_tasks
  end
end
