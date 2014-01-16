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

include Appscript

##
# Synchronizes bug tracking systems to omnifocus.
#
# Some definitions:
#
# bts: bug tracking system
# SYSTEM: a tag uniquely identifying the bts
# bts_id: a string uniquely identifying a task: SYSTEM(-projectname)?#id

class OmniFocus
  VERSION = '2.1.3'

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

  def self._load_plugins
    @__loaded__ ||=
      begin
        filter = ARGV.shift
        loaded = {}
        Gem.find_files("omnifocus/*.rb").each do |path|
          name = File.basename path
          next if loaded[name]
          next unless path.index filter if filter
          require path
          loaded[name] = true
        end
        true
      end
  end

  def initialize
    @bug_db   = Hash.new { |h,k| h[k] = {} }
    @existing = {}
  end

  def its # :nodoc:
    Appscript.its
  end

  def omnifocus
    @omnifocus ||= Appscript.app('OmniFocus').default_document
  end

  def all_subtasks task
    [task] + task.tasks.get.flatten.map{|t| all_subtasks(t) }
  end

  def all_tasks
    # how to filter on active projects. note, this causes sync problems
    # omnifocus.flattened_projects[its.status.eq(:active)].tasks.get.flatten
    omnifocus.flattened_projects.tasks.get.flatten.map{|t| all_subtasks(t) }.flatten
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
    prefixen = self.class._plugins.map { |klass| klass::PREFIX rescue nil }
    of_tasks = nil

    prefix_re = /^(#{Regexp.union prefixen}(?:-[\w\s.-]+)?\#\d+)/

    if prefixen.all? then
      of_tasks = all_tasks.find_all { |task|
        task.name.get =~ prefix_re
      }
    else
      warn "WA"+"RN: Older plugins installed. Falling back to The Old Ways"

      of_tasks = all_tasks.find_all { |task|
        task.name.get =~ /^([A-Z]+(?:-[\w-]+)?\#\d+)/
      }
    end

    of_tasks.each do |of_task|
      ticket_id = of_task.name.get[prefix_re, 1]
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

  def self._plugins
    _load_plugins

    constants.
      reject { |mod| mod =~ /^[A-Z_]+$/ }.
      map    { |mod| const_get mod }.
      reject { |mod| Class === mod }
  end

  def cmd_sync args
    # do this all up front so we can REALLY fuck shit up with plugins
    self.class._plugins.each do |plugin|
      extend plugin
    end

    prepopulate_existing_tasks

    self.class._plugins.each do |plugin|
      name = plugin.name.split(/::/).last.downcase
      warn "scanning #{name}"
      send "populate_#{name}_tasks"
    end

    if $DEBUG then
      require 'pp'
      p :existing
      pp existing
      p :bug_db
      pp bug_db
    end

    create_missing_projects
    update_tasks
  end
end

class Object
  def nilify
    self == :missing_value ? nil : self
  end
end

class OmniFocus
  def self.method_missing(msg, *args)
    of = OmniFocus.new
    of.send("cmd_#{msg}", *args)
  end

  def top hash, n=10
    hash.sort_by { |k,v| [-v, k] }.first(n).map { |k,v|
      "%4d %s" % [v,k[0,21]]
    }
  end

  def cmd_neww args
    project_name = args.shift
    title = ($stdin.tty? ? args.join(" ") : $stdin.read).strip

    unless project_name && ! title.empty? then
      cmd = File.basename $0
      projects = omnifocus.flattened_projects.name.get.sort_by(&:downcase)

      warn "usage: #{cmd} new project_name title        - create a project task"
      warn "       #{cmd} new nil          title        - create an inbox task"
      warn "       #{cmd} new project      project_name - create a new project"
      warn ""
      warn "project_names = #{projects.join ", "}"
      exit 1
    end

    case project_name.downcase
    when "nil" then
      omnifocus.make :new => :inbox_task, :with_properties => {:name => title}
    when "project" then
      rep        = weekly
      start_date = hour 0
      due_date1  = hour 16
      due_date2  = hour 16.5

      cont = context("Releasing").thing
      proj = make nerd_projects, :project, title, :review_interval => rep

      props = {
        :repetition => rep,
        :context    => cont,
        :start_date => start_date
      }

      make proj, :task, "Release #{title}", props.merge(:due_date => due_date1)
      make proj, :task, "Triage #{title}", props.merge(:due_date => due_date2)
    else
      projects = omnifocus.sections.projects[its.name.eq(project_name)]
      project = projects.get.flatten.grep(Appscript::Reference).first
      project.make :new => :task, :with_properties => {:name => title}

      puts "created task in #{project_name}: #{title}"
    end
  end

  def weekly n=1
    {
      :unit => :week,
      :steps => n,
      :fixed_ => true,
    }
  end

  def add_hours t, n
    t + (n * 3600).to_i
  end

  def hour n
    t = Time.now
    midnight = Time.gm t.year, t.month, t.day
    midnight -= t.utc_offset
    midnight + (n * 3600).to_i
  end

  def cmd_projects args
    h = Hash.new 0
    n = 0

    self.active_projects.each do |project|
      name  = project.name
      count = project.unscheduled_tasks.size
      ri    = project.review_interval
      time  = "#{ri[:steps]}#{ri[:unit].to_s[0,1]}"

      next unless count > 0

      n += count
      h["#{name} (#{time})"] = count
    end

    puts "%5d: %3d%%: %s" % [n, 100, "Total"]
    puts
    h.sort_by { |name, count| -count }.each do |name, count|
      puts "%5d: %3d%%: %s" % [count, 100 * count / n, name]
    end
  end

  def cmd_wtf args
    filter = its.completed.eq(false).and(its.repetition.eq(:missing_value))

    h1 = Hash.new 0
    omnifocus.flattened_contexts.get.each do |context|
      context.tasks[filter].get.each do |task|
        h1[[task.containing_project.name.get, context.name.get].join(": ")] += 1
      end
    end

    h2 = Hash.new 0
    omnifocus.flattened_contexts.get.each do |context|
      h2[context.name.get] += context.tasks[filter].count
    end

    h3 = Hash.new 0
    omnifocus.flattened_projects.get.each do |project|
      h3[project.name.get] += project.tasks[filter].count
    end

    top(h1).zip(top(h2), top(h3)).each do |a|
      puts "%-26s%-26s%-26s" % a
    end
  end

  def cmd_help args
    methods = OmniFocus.public_instance_methods(false).grep(/^cmd_/)
    methods.map! { |s| s[4..-1] }

    puts "Available subcommands:"

    methods.sort.each do |m|
      puts "  #{m}"
    end
  end

  def cmd_schedule args
    name = args.shift or abort "need a context or project name"

    cp = context(name) || project(name)

    abort "Context/Project not found: #{name}" unless cp

    print_aggregate_report cp.tasks, :long
  end

  def cmd_fix_review_dates args # TODO: merge into reschedule
    skip = ARGV.first == "-n"

    projs = Hash.new { |h,k| h[k] = [] }

    all_projects.each do |proj|
      ri   = proj.review_interval

      projs[ri[:steps]] << proj
    end

    projs.each do |k, a|
      # helps stabilize and prevent random shuffling
      projs[k] = a.sort_by { |p| [p.next_review_date, p.name] }
    end

    now = hour 0
    fri = if now.wday == 5 then
            now
          else
            now - 86400 * (now.wday-5)
          end

    no_autosave_during do
      projs.each do |unit, a|
        day = fri

        steps = (a.size.to_f / unit).ceil

        a.each_with_index do |proj, i|
          if proj.next_review_date != day then
            warn "Fixing #{unit} #{proj.name} to #{day}"
            proj.thing.next_review_date.set day unless skip
          end

          day += 86400 * 7 if (i+1) % steps == 0
        end
      end
    end
  end

  def distribute count, weeks
    count = count.to_f
    d = 5 * weeks
    hits = (1..d).step(d/count).map(&:round)
    (1..d).map { |n| hits.include?(n) ? weeks : nil }
  end

  def calculate_schedule projs
    all = [
           distribute(projs[1].size, 1),
           distribute(projs[2].size, 2),
           distribute(projs[3].size, 3),
           distribute(projs[5].size, 5),
           distribute(projs[7].size, 7),
          ]

    # [[1, 1, 1, 1, 1],
    #  [2, 2, 2, 2, 2, nil, 2, 2, 2, 2],
    #  [3, nil, 3, 3, nil, 3, 3, nil, 3, 3, nil, 3, 3, nil, 3],
    #  ...

    all.map! { |a|
      a.concat [nil] * (35-a.size)
      a.each_slice(5).to_a
    }

    # [[[1, 1, 1, 1, 1],     [nil, nil, nil, nil, nil], ...
    #  [[2, 2, 2, 2, 2],     [nil, 2, 2, 2, 2],         ...
    #  [[3, nil, 3, 3, nil], [3, 3, nil, 3, 3],         ...
    #  ...

    weeks = all.transpose.map { |a, *r|
      a.zip(*r).map(&:compact)
    }

    # [[[1, 2, 3, 5, 7], [1, 2], [1, 2, 3], [1, 2, 3], [1, 2, 5]],
    #  [[3], [2, 3, 7], [2], [2, 3, 5], [2, 3]],
    #  ...

    weeks
  end

  def aggregate_releases
    rels = context "Releasing"

    tasks = Hash.new { |h,k| h[k] = [] } # name => tasks
    projs = Hash.new { |h,k| h[k] = [] } # step => projs

    rels.tasks.each do |task|
      proj = task.project
      tasks[proj.name] << task
      projs[proj.review_interval[:steps]] << proj
    end

    projs.each do |k, a|
      # helps stabilize and prevent random shuffling
      projs[k] = a.uniq_by { |p| p.name }.sort_by { |p|
        tasks[p.name].map(&:name).min
      }
    end

    return rels, tasks, projs
  end

  def fix_project_review_intervals rels, skip
    rels.tasks.each do |task|
      proj = task.project

      t_ri = task.repetition[:steps]
      p_ri = proj.review_interval[:steps]

      if t_ri != p_ri then
        warn "Fixing #{task.name} to #{p_ri} weeks"

        rep = {
          :recurrence        => "FREQ=WEEKLY;INTERVAL=#{p_ri}",
          :repetition_method => :fixed_repetition,
        }

        task.thing.repetition_rule.set :to => rep unless skip
      end
    end
  end

  def fix_release_task_names projs, tasks, skip
    projs.each do |step, projects|
      projects.each do |project|
        tasks[project.name].each do |task|
          if task.name =~ /^(\d+(\.\d+)?)/ then
            if $1.to_i != step then
              new_name = task.name.sub(/^(\d+(\.\d+)?)/, step.to_s)
              puts "renaming to #{new_name}"
              task.thing.name.set new_name unless skip
            end
          end
        end
      end
    end
  end

  def fix_release_task_schedule projs, tasks, skip
    weeks = calculate_schedule projs

    now = hour 0
    mon = if now.wday == 1 then
            now
          else
            now - 86400 * (now.wday-1)
          end

    weeks.each_with_index do |week, wi|
      week.each_with_index do |day, di|
        next if day.empty?
        delta = wi*7 + di
        date = mon + 86400 * delta

        day.each do |rank|
          p = projs[rank].shift
          t = tasks[p.name]

          t.each do |task|
            if task.start_date != date then
              due_date1  = add_hours date, 16
              due_date2  = add_hours date, 16.5

              warn "Fixing #{p.name} to #{date.strftime "%Y-%m-%d"}"

              next if skip

              case task.name
              when /Release/ then
                task.start_date = date
                task.due_date = due_date1
              when /Triage/ then
                task.start_date = date
                task.due_date = due_date2
              else
                warn "Unknown task name: #{task.name}"
              end
            end
          end
        end
      end
    end
  end

  def cmd_reschedule args
    skip = ARGV.first == "-n"

    rels, tasks, projs = aggregate_releases

    no_autosave_during do
      warn "Checking project review intervals..."
      fix_project_review_intervals rels, skip

      warn "Checking releasing task numeric prefixes (if any)"
      fix_release_task_names projs, tasks, skip

      warn "Checking releasing task schedules"
      fix_release_task_schedule projs, tasks, skip
    end
  end

  def cmd_time args
    m = 0

    all_tasks.map { |task|
      task.estimated_minutes.get
    }.grep(Numeric).each { |t|
      m += t
    }

    puts "all tasks = #{m} minutes"
    puts "          = %.2f hours" % (m / 60.0)
  end

  def cmd_review args
    print_aggregate_report all_projects
  end

  class Thingy
    attr_accessor :omnifocus, :thing
    def initialize of, thing
      @omnifocus = of
      @thing = thing
    end

    def active
      its.completed.eq(false)
    end

    def method_missing m, *a
      warn [m,*a].inspect
      thing.send m, *a
    end

    def name
      thing.name.get
    end

    def id
      thing.id_.get
    end

    def inspect
      "#{self.class}[#{self.id}]"
    end
  end

  class Project < Thingy
    def unscheduled
      its.due_date.eq(:missing_value)
    end

    def unscheduled_tasks
      thing.tasks[active.and(unscheduled)].get.map { |t|
        Task.new omnifocus, t
      }
    end

    def review_interval
      thing.review_interval.get
    end

    def review_interval= h
      thing.review_interval.set :to => h
    end

    def next_review_date
      thing.next_review_date.get
    end

    def tasks
      thing.tasks[active].get.map { |t| Task.new omnifocus, t }
    end
  end

  class Task < Thingy
    def project
      Project.new omnifocus, thing.containing_project.get
    end

    def start_date= t
      thing.start_date.set t
    end

    def start_date
      thing.start_date.get.nilify
    end

    def due_date= t
      thing.due_date.set t
    end

    def due_date
      thing.due_date.get.nilify
    end

    def repetition
      thing.repetition.get.nilify
    end

    def completed
      thing.completed.get.nilify
    end
  end

  class Context < Thingy
    def tasks
      thing.tasks[active].get.map { |t| Task.new omnifocus, t }
    end
  end

  def print_aggregate_report collection, long = false
    h, p = self.aggregate collection

    self.print_occurrence_table h, p

    puts

    self.print_details h, long
  end

  def aggregate collection
    h = Hash.new { |h1,k1| h1[k1] = Hash.new { |h2,k2| h2[k2] = [] } }
    p = Hash.new 0

    collection.each do |thing|
      name = thing.name
      ri   = case thing
             when Project then
               thing.review_interval
             when Task then
               thing.repetition
             else
               raise "unknown type: #{thing.class}"
             end
      date = case thing
             when Project then
               thing.next_review_date
             when Task then
               thing.due_date
             else
               raise "unknown type: #{thing.class}"
             end

      date = if date then
               date.strftime("%Y-%m-%d %a")
             else
               "unscheduled"
             end

      time = ri ? "#{ri[:steps]}#{ri[:unit].to_s[0,1]}" : "NR"

      p[time] += 1
      h[date][time] << name
    end

    return h, p
  end

  def print_occurrence_table h, p
    p = p.sort_by { |priority, _|
      case priority
      when /(\d+)(.)/ then
        n, u = $1.to_i, $2
        n *= {"d" => 1, "w" => 7, "m" => 28, "y" => 365}[u]
      when "NR" then
        1/0.0
      else
        warn "unparsed: #{priority.inspect}"
        0
      end
    }

    units = p.map(&:first)

    total = 0
    hdr = "%14s%s %3s " + "%2s " * units.size
    fmt = "%14s: %3d " + "%2s " * units.size
    puts hdr % ["date", "\\", "tot", *units]
    h.sort.each do |date, plan|
      counts = units.map { |n| plan[n].size  }
      subtot = counts.inject(&:+)
      total += subtot
      puts fmt % [date, subtot, *counts]
    end
    puts hdr % ["total", ":", total, *p.map(&:last)]
  end

  def print_details h, long = false
    h.sort.each do |date, plan|
      puts date
      plan.sort.each do |period, things|
        next if things.empty?
        if long then
          things.sort.each do |thing|
            puts "  #{period}: #{thing}"
          end
        else
          puts "  #{period}: #{things.sort.join ', '}"
        end
      end
    end
  end

  def active_project
    its.status.eq(:active)
  end

  def all_projects
    self.omnifocus.flattened_projects.get.map { |p|
      Project.new omnifocus, p
    }
  end

  def all_contexts
    self.omnifocus.flattened_contexts.get.map { |c|
      Context.new omnifocus, c
    }
  end

  def context name
    context = self.omnifocus.flattened_contexts[name].get rescue nil
    Context.new omnifocus, context if context
  end

  def project name
    project = self.omnifocus.flattened_projects[name].get
    Project.new omnifocus, project if project
  end

  def active_projects
    self.omnifocus.flattened_projects[active_project].get.map { |p|
      Project.new omnifocus, p
    }
  end

  def regular_tasks
    (its.value.class_.eq(:item).not).and(its.value.class_.eq(:folder).not)
  end

  def window
    self.omnifocus.document_windows[1]
  end

  def selected_tasks
    window.content.selected_trees[regular_tasks].value.get.map { |t|
      Task.new self, t
    }
  end

  def no_autosave_during
    self.omnifocus.will_autosave.set false
    yield
  ensure
    self.omnifocus.will_autosave.set true
  end
end

class Array
  def merge! o
    o.each_with_index do |x, i|
      self[i] << x
    end
  end
end

module Enumerable
  def uniq_by
    r, s = [], {}
    each do |e|
      v = yield(e)
      next if s[v]
      r << e
      s[v] = true
    end
    r
  end
end unless [].respond_to?(:uniq_by)
