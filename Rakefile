# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :seattlerb
Hoe.plugin :isolate

Hoe.spec "omnifocus" do
  developer "Ryan Davis", "ryand-ruby@zenspider.com"
  developer "aja", "kushali@rubyforge.org"

  license "MIT"

  dependency "rb-scpt", "~> 1.0"
  dependency "mechanize", "~> 2.0"
  dependency "octokit",   "~> 4.14", :development if ENV["TEST"]

  pluggable!
end

def omnifocus cmd, options = nil
  inc = "-Ilib:../../omnifocus-github/dev/lib"

  ruby "#{inc} bin/of #{cmd} #{options}"
end

task :sync => :isolate do
  omnifocus "sync github"
end

task :fix => :isolate do
  omnifocus "fix"
  omnifocus "resch"
end

task :rev => :isolate do
  omnifocus "rev"
end

task :debug => :isolate do
  cmd = ENV["CMD"] || "sync github"
  d = ENV["D"] ? "-d" : nil
  omnifocus cmd, d
end

# vim: syntax=ruby
