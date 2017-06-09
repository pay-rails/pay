# Pay
Short description and motivation.

Requires Rails 4.2+?

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'pay'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install pay
```

## Usage
`$ bin/rails pay:install:migrations`

This will install migrations for:
- Creating a Subscription Table
- Adding fields to your users (or whatever class you want)

Include the `Pay::Billable` module in the model you want to know about subscriptions.

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
