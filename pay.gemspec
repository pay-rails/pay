$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "pay/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "pay"
  s.version     = Pay::VERSION
  s.authors     = ["Jason Charnes"]
  s.email       = ["jason@thecharnes.com"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of Pay."
  s.description = "TODO: Description of Pay."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 5.0.1"

  s.add_development_dependency "sqlite3"
end
