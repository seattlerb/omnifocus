class OmniFocus
  desc "Reschedule reviews & releases, and fix missing tasks. -n to no-op"
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

      warn "Repairing any missing release or triage tasks"
      fix_missing_tasks skip
    end
  end
end
