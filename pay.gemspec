$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'pay/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'pay'
  s.version     = Pay::VERSION
  s.authors     = ['Jason Charnes']
  s.email       = ['jason@thecharnes.com']
  s.homepage    = 'https://github.com/jasoncharnes/pay'
  s.summary     = 'A Ruby on Rails subscription engine.'
  s.description = 'A Ruby on Rails subscription engine.'
  s.license     = 'MIT'

  s.files = Dir[
    '{app,config,db,lib}/**/*',
    'MIT-LICENSE',
    'Rakefile',
    'README.md'
  ]

  s.add_dependency 'braintree', '~> 2.80'
  s.add_dependency 'rails', '>= 4.2'
  s.add_dependency 'rails-html-sanitizer', '~> 1.0.4'
  s.add_dependency 'stripe', '~> 3.22'
  s.add_dependency 'stripe_event', '~> 2.1'

  s.add_development_dependency 'byebug'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'stripe-ruby-mock', '~> 2.5'
end
