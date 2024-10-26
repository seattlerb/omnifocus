class OmniFocus
  desc "Print out an aggregate report for all live projects"
  def cmd_review args
    print_aggregate_report live_projects
  end
end
