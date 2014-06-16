# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :seattlerb
Hoe.plugin :isolate

Hoe.spec "omnifocus" do
  developer "aja", "kushali@rubyforge.org"
  developer "Ryan Davis", "ryand-ruby@zenspider.com"

  license "MIT"

  dependency "rb-appscript", "~> 0.6.1"
  dependency "mechanize",    "~> 2.0"

  pluggable!
end

inc = "-Ilib:../../omnifocus-github/dev/lib:../../omnifocus-redmine/dev/lib"

task :sync => :isolate do
  ENV["GEM_PATH"] = File.expand_path "~/.gem/sandboxes/omnifocus"

  ruby "#{inc} bin/of sync"
end

task :debug => :isolate do
  ENV["GEM_PATH"] = File.expand_path "~/.gem/sandboxes/omnifocus"

  ruby "-d #{inc} bin/of sync github"
end

# vim: syntax=ruby
