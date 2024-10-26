# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :seattlerb
Hoe.plugin :isolate

Hoe.spec "omnifocus" do
  developer "Ryan Davis", "ryand-ruby@zenspider.com"

  license "MIT"

  dependency "rb-scpt", "~> 1.0"
  dependency "octokit",   "~> 4.14", :development if ENV["TEST"] || ENV["USER"] == "ryan"

  self.isolate_multiruby = true

  pluggable!
end

def omnifocus cmd, options = nil
  inc = "-Ilib:../../omnifocus-github/dev/lib"

  ruby "#{inc} -rpry-byebug bin/of #{cmd} #{options}"
end

desc "Run fix and reschedule tasks"
t = task "of:fix" => :isolate do
  omnifocus "fix"
  omnifocus "resch"
end
t.plugin = "omnifocus"

desc "Run any command (via $CMD) with -d if $D"
t = task "of:debug" => :isolate do
  cmd = ENV["CMD"] || "sync github"
  d = ENV["D"] ? "-d" : nil
  omnifocus cmd, d
end
t.plugin = "omnifocus"

Dir["lib/omnifocus/*.rb"]
  .map { |f| File.basename f, ".rb" }
  .each do |cmd|
    desc "Run the #{cmd} command"
    task("of:#{cmd}" => :isolate) { omnifocus cmd }
      .plugin = "omnifocus"
  end

# vim: syntax=ruby
