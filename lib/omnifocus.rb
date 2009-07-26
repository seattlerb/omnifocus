require 'rubygems'
require 'mechanize'
require 'rubyforge'
require 'appscript'

# (Roughly) Equivalent Applescript:
#
#   tell application "OmniFocus"
#     set nerd_projects to first section of document 1 whose name is "nerd"
#     set pt to first project of nerd_projects whose name is "parsetree"
#     tell pt to make new task with properties {name:bug_title, note:bug_url}
#   end tell

class Rf2of
  VERSION = '1.0.0'

  attr_reader :bug_db, :existing

  def initialize
    # bug_db = {
    #   project => {
    #     rf_id => [name, url], # only on RF = add to OF
    #     rf_id => true,        # seen on OF = don't touch in OF
    #     rf_id => false,       # only on OF = remove from OF
    #   }
    # }

    @bug_db = Hash.new { |h,k| h[k] = {} }

    # existing = {
    #   rf_id => project,
    # }

    @existing = {}
  end

  def its
    Appscript.its
  end

  def nerd_projects
    unless defined? @nerd_projects then
      omnifocus      = Appscript.app('OmniFocus').documents[1]
      @nerd_projects = omnifocus.sections[its.name.eq("nerd")].first
    end

    @nerd_projects
  end

  def prepopulate_existing_tasks
    of_tasks = nerd_projects.projects.tasks[its.name.contains("#")].get.flatten
    of_tasks.each do |of_task|
      # of_task.completed.set false
      ticket_id                  = of_task.name.get[/^[A-Z]+#(\d+)/, 1].to_i
      project                    = of_task.containing_project.name.get
      existing[ticket_id]        = project
      bug_db[project][ticket_id] = false
    end
  end

  def rf
    unless defined? @rf then
      @rf = RubyForge.new
      @rf.configure
    end
    @rf
  end

  def mechanize
    @mechanize ||= WWW::Mechanize.new
  end

  def create_missing_projects
    (bug_db.keys - nerd_projects.projects.name.get).each do |name|
      nerd_projects.make :new => :project, :with_properties => { :name => name }
    end
  end

  def update_tasks
    bug_db.each do |name, tickets|
      project = nerd_projects.projects[its.name.eq(name)].projects[1]

      project.tasks[its.name.contains("RF#")].get.each do |task|
        ticket_id = task.name.get[/RF#(\d+)/, 1].to_i
        next if ticket_id == 0 or tickets[ticket_id] or task.completed.get

        puts "removing #{name} # #{ticket_id}"
        task.completed.set true
      end

      tasks = project.tasks.name.get.map { |s| s[/RF#(\d+)/, 1].to_i }

      tickets.each do |ticket_id, (title, url)|
        next if tasks.include? ticket_id
        next unless url
        puts "creating #{name} # #{ticket_id}"
        project.make(:new => :task,
                     :with_properties => {
                       :note => url,
                       :name => "RF##{ticket_id}: #{title}",
                     })
      end
    end
  end

  def self.plugins
    constants.reject { |mod| mod =~ /^[A-Z_]+$/ }.map { |mod| const_get mod }
  end

  def go
    prepopulate_existing_tasks

    self.class.plugins.each do |plugin|
      extend plugin
      name = plugin.name.split(/::/).last.downcase
      send "populate_#{name}_tasks"
    end

    if false then
      require 'pp'
      pp bug_db
    else
      create_missing_projects
      update_tasks
    end
  end

  module Rubyforge
    RF_URL = "http://rubyforge.org"

    def get_rubyforge_tickets
      m  = mechanize

      login_url = "/account/login.php"
      home = m.get("#{RF_URL}#{login_url}").form_with(:action => login_url) do |f|
        f.form_loginname = rf.userconfig["username"]
        f.form_pw        = rf.userconfig["password"]
      end.click_button

      # nuke all the tracker links on "My Page" after "My Submitted Items"
      node = home.root.xpath('//tr[td[text() = "My Submitted Items"]]').first
      loop do
        prev, node = node, node.next
        prev.remove
        break unless node
      end

      home.links_with(:href => /^.tracker/)
    end

    def populate_rubyforge_tasks
      group_ids = rf.autoconfig["group_ids"].invert

      get_rubyforge_tickets.each do |link|
        if link.href =~ /func=detail&aid=(\d+)&group_id=(\d+)&atid=(\d+)/ then
          ticket_id, group_id = $1.to_i, $2.to_i
          group = group_ids[group_id]

          next unless group

          if existing[ticket_id] then
            bug_db[existing[ticket_id]][ticket_id] = true
            next
          end

          warn "scanning ticket RF##{ticket_id}"
          details = link.click.form_with :action => /^.tracker/
          select  = details.field_with   :name   => "category_id"
          project = select.selected_options.first
          project = project ? project.text.downcase : group
          project = group if project =~ /\s/

          bug_db[project][ticket_id] = [link.text, "#{RF_URL}/#{link.href}"]
        end
      end
    end
  end
end
