class OmniFocus
  desc "Create a new project or task"
  def cmd_neww args
    project_name = args.shift
    title = ($stdin.tty? ? args.join(" ") : $stdin.read).strip

    unless project_name && ! title.empty? then
      cmd = File.basename $0
      projects = self.omnifocus.flattened_projects.name.get.sort_by(&:downcase)

      warn "usage: #{cmd} new project_name title        - create a project task"
      warn "       #{cmd} new nil          title        - create an inbox task"
      warn "       #{cmd} new project      project_name - create a new project"
      warn ""
      warn "project_names = #{projects.join ", "}"
      exit 1
    end

    case project_name.downcase
    when "nil" then
      self.omnifocus.make :new => :inbox_task, :with_properties => {:name => title}
    when "project" then
      new_or_repair_project title
    else
      project = self.omnifocus.flattened_projects[q_named(project_name)].first.get
      make project, :task, title
      puts "created task in #{project_name}: #{title}"
    end
  end
end
