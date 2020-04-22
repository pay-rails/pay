require "bundler/gem_tasks"
require "rake/testtask"
require "rdoc/task"

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "Pay"
  rdoc.options << "--line-numbers"
  rdoc.rdoc_files.include("README.md")
  rdoc.rdoc_files.include("lib/**/*.rb")
end

APP_RAKEFILE = File.expand_path("../test/dummy/Rakefile", __FILE__)

load "rails/tasks/engine.rake"
load "rails/tasks/statistics.rake"


Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.verbose = false
end

task default: :test

task :console do
  require "irb"
  require "irb/completion"
  require "pay"
  ARGV.clear
  IRB.start
end
