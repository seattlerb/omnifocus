class OmniFocus
  desc "Print out all active projects"
  def cmd_projects args
    h = Hash.new 0
    n = 0

    self.active_nerd_projects.each do |project|
      name  = project.name
      count = project.flattened_tasks.count
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

    t = Hash.new { |h,k| h[k] = [] }

    self.active_nerd_projects.each do |project|
      ri    = project.review_interval
      time  = "#{ri[:steps]}#{ri[:unit].to_s[0,1]}"

      t[time] << project.name
    end

    puts
    t.sort.each do |k, vs|
      wrapped = vs.sort
        .join(" ")              # make one string
        .scan(/.{,70}(?: |$)/)  # break into 70 char lines
        .join("\n    ")         # wrap w/ whitespace to indent
        .strip

      puts "%s: %s" % [k, wrapped]
      puts
    end
  end
end
