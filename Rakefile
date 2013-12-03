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
  dependency "mechanize",    "~> 1.0"

  pluggable!
end

task :sync => :isolate do
  ruby "-Ilib:../../omnifocus-github/dev/lib bin/of sync github"
end

task :debug => :isolate do
  ruby "-d -Ilib:../../omnifocus-github/dev/lib bin/of sync github"
end

# vim: syntax=ruby
