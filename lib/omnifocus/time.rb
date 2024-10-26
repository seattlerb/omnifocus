class OmniFocus
  desc "Calculate the amount of estimated time across all tasks. Depressing"
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
end
