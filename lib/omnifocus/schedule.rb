class OmniFocus
  desc "Print out a schedule for a project or context"
  def cmd_schedule args
    name = args.shift or abort "need a context or project name"

    cp = context(name) || project(name)

    abort "Context/Project not found: #{name}" unless cp

    print_aggregate_report cp.tasks, :long
  end
end
