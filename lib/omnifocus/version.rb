class OmniFocus
  desc "Print out versions for omnifocus and plugins"
  def cmd_version args
    plugins = self.class._plugins

    width = plugins.map(&:name).map(&:length).max
    fmt = "  %-#{width}s = v%s"

    puts "Versions:"
    puts

    puts fmt % ["Omnifocus", VERSION]
    plugins.each do |klass|
      puts fmt % [klass, klass::VERSION]
    end
  end
end
