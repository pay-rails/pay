module Pay
  module Lago
    autoload :Billable, "pay/lago/billable"
    autoload :Charge, "pay/lago/charge"
    autoload :Error, "pay/lago/error"
    autoload :PaymentMethod, "pay/lago/payment_method"
    autoload :Subscription, "pay/lago/subscription"
    autoload :Merchant, "pay/lago/merchant"
  end
end
