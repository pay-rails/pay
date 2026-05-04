$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "pay/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name = "pay"
  spec.version = Pay::VERSION
  spec.authors = ["Jason Charnes", "Chris Oliver", "Collin Jilbert"]
  spec.email = ["jason@thecharnes.com", "excid3@gmail.com", "cjilbert504@gmail.com"]
  spec.homepage = "https://github.com/pay-rails/pay"
  spec.summary = "Payments engine for Ruby on Rails"
  spec.description = "Stripe, Paddle, and Braintree payments for Ruby on Rails apps"
  spec.license = "MIT"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "{app,config,db,lib}/**/*",
    "MIT-LICENSE",
    "Rakefile",
    "README.md"
  ]

  spec.add_dependency "rails", ">= 7.0.0"
end
