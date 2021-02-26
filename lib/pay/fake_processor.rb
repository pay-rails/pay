module Pay
  module FakeProcessor
    autoload :Billable, "pay/fake_processor/billable"
    autoload :Charge, "pay/fake_processor/charge"
    autoload :Subscription, "pay/fake_processor/subscription"
    autoload :Error, "pay/fake_processor/error"
  end
end
