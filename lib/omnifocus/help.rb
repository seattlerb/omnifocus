class OmniFocus
  desc "Print out descriptions for all known subcommands"
  def cmd_help args
    methods = OmniFocus.public_instance_methods(false).grep(/^cmd_/)
    methods.map! { |s| s[4..-1] }
    width = methods.map(&:length).max

    puts "Available subcommands:"

    methods.sort.each do |m|
      desc = self.class.description["cmd_#{m}".to_sym]
      puts "  %-#{width}s : %s." % [m, desc]
    end
  end
end
