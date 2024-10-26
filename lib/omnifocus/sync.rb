class OmniFocus
  desc "Synchronize tasks with all known BTS plugins"
  def cmd_sync args
    self.debug = args.delete("-d")
    plugins = self.class._plugins

    # do this all up front so we can REALLY fuck shit up with plugins
    plugins.each do |plugin|
      extend plugin
    end

    prepopulate_existing_tasks

    plugins.each do |plugin|
      name = plugin.name.split(/::/).last.downcase
      warn "scanning #{name}"
      send "populate_#{name}_tasks"
    end

    if debug then
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
