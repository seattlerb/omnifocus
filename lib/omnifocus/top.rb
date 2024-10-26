class OmniFocus
  desc "Print out top 10 projects+contexts, contexts, and projects"
  def cmd_top args
    # available non-repeating tasks per project & context
    h1 = Hash.new 0
    _flattened_contexts.each do |context|
      context_name = context.name.get
      context.tasks[q_active_unique].get.each do |task|
        h1[[task.containing_project.name.get, context_name].join(": ")] += 1
      end
    end

    # available non-repeating tasks per context
    h2 = Hash.new 0
    _flattened_contexts.each do |context|
      h2[context.name.get] += context.tasks[q_active_unique].count
    end

    # available non-repeating tasks per project
    h3 = Hash.new 0
    self.omnifocus.flattened_projects.get.each do |project|
      h3[project.name.get] += project.flattened_tasks[q_active_unique].count
    end

    puts "%-26s%-26s%-26s" % ["#### Proj+Context", "#### Context", "#### Project"]
    puts "-" * 26 * 3
    top(h1).zip(top(h2), top(h3)).each do |a|
      puts "%-26s%-26s%-26s" % a
    end
  end
end
