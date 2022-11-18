module Pay
  module FakeProcessor
    autoload :Billable, "pay/fake_processor/billable"
    autoload :Charge, "pay/fake_processor/charge"
    autoload :Error, "pay/fake_processor/error"
    autoload :PaymentMethod, "pay/fake_processor/payment_method"
    autoload :Subscription, "pay/fake_processor/subscription"
    autoload :Merchant, "pay/fake_processor/merchant"
  end
end
