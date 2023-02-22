class Omnifocus
  desc "Set the schedule for a project (incl release and triage tasks) to N weeks"
  def cmd_set args
    name, interval = args

    abort "NAH" unless name && interval

    interval = interval.to_i

    proj = project name

    if proj.review_interval[:steps] != interval then
      warn "Setting project review to #{interval} weeks"
      proj.review_interval = weekly(interval)
    end

    rel = proj.thing.tasks[q_release].first.get rescue nil # TODO: this sucks
    tri = proj.thing.tasks[q_triage].first.get rescue nil

    fix_project_review_interval Task.new(omnifocus, rel) if rel
    fix_project_review_interval Task.new(omnifocus, tri) if tri
  end
end
