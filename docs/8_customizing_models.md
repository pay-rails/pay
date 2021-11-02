# Customizing Pay Models

Want to add functionality to a Pay model? You can define a concern and simply include it in the model when Rails loads the code.

First, you'll need to create a concern with the functionality you'd like to add.

```ruby
# app/models/concerns/charge_extensions.rb
module ChargeExtensions
  extend ActiveSupport::Concern

  included do
    belongs_to :order
    after_create :fulfill_order
  end

  def fulfill_order
    order.fulfill!
  end
end
```

Then you can tell Rails to include the concern whenever it loads the application.

```ruby
# config/initializers/pay.rb

# Re-include the ChargeExtensions every time Rails reloads
Rails.application.config.to_prepare do
  Pay::Charge.include ChargeExtensions
end
```

## Next

See [Testing](9_testing.md)
