$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "pay/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name = "pay"
  s.version = Pay::VERSION
  s.authors = ["Jason Charnes", "Chris Oliver"]
  s.email = ["jason@thecharnes.com", "excid3@gmail.com"]
  s.homepage = "https://github.com/pay-rails/pay"
  s.summary = "Payments engine for Ruby on Rails"
  s.description = "Stripe, Paddle, and Braintree payments for Ruby on Rails apps"
  s.license = "MIT"

  s.files = Dir[
    "{app,config,db,lib}/**/*",
    "MIT-LICENSE",
    "Rakefile",
    "README.md"
  ]

  s.add_dependency "rails", ">= 4.2"

  s.add_development_dependency "minitest-rails", ">= 6", "< 7.0"
  s.add_development_dependency "mocha"
  s.add_development_dependency "standardrb"
  s.add_development_dependency "vcr"
  s.add_development_dependency "webmock"
end
