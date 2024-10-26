class OmniFocus
  desc "Start a pry repl"
  def cmd_repl args
    puts "starting pry..."
    require "pry"
    binding.pry
    p :DONE
  end
end
