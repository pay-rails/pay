# Rakefile task for running Metamask tests
# Add to your Rakefile or create a separate file in lib/tasks/

namespace :test do
  desc 'Run all Metamask payment processor tests (unit + integration)'
  task :metamask do
    require 'rake/testtask'

    Rake::TestTask.new do |t|
      t.libs << 'test'
      t.pattern = 'test/pay/metamask/{unit,integration}_test.rb'
      t.verbose = true
    end.invoke
  end

  desc 'Run Metamask unit tests only'
  task :metamask_unit do
    require 'rake/testtask'

    Rake::TestTask.new do |t|
      t.libs << 'test'
      t.pattern = 'test/pay/metamask/unit_test.rb'
      t.verbose = true
    end.invoke
  end

  desc 'Run Metamask integration tests only'
  task :metamask_integration do
    require 'rake/testtask'

    Rake::TestTask.new do |t|
      t.libs << 'test'
      t.pattern = 'test/pay/metamask/integration_test.rb'
      t.verbose = true
    end.invoke
  end

  desc 'Run Metamask E2E tests (requires PLAYWRIGHT=true)'
  task :metamask_e2e do
    require 'rake/testtask'

    ENV['PLAYWRIGHT'] = 'true'

    Rake::TestTask.new do |t|
      t.libs << 'test'
      t.pattern = 'test/pay/metamask/e2e_test.rb'
      t.verbose = true
    end.invoke
  end

  desc 'Run all Metamask tests including E2E (requires PLAYWRIGHT=true)'
  task :metamask_all do
    require 'rake/testtask'

    ENV['PLAYWRIGHT'] = 'true'

    Rake::TestTask.new do |t|
      t.libs << 'test'
      t.pattern = 'test/pay/metamask/*_test.rb'
      t.verbose = true
    end.invoke
  end
end

# Optional: Run Metamask tests by default if METAMASK env var is set
namespace :test do
  task :prepare do
    Rake::Task['test:metamask'].invoke if ENV['METAMASK']
  end
end
