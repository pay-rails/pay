namespace :pay do
  namespace :payment_methods do
    desc "Sync default payment methods for Pay::Customers"
    task sync_default: :environment do
      Pay::Customer.find_each do |pay_customer|
        sync_default_payment_method(pay_customer)
      end
    end
  end
end

def sync_default_payment_method(pay_customer, retries: 2)
  try = 0
  begin
    puts "Syncing Pay::Customer ##{pay_customer.id} attempt #{try + 1}: #{pay_customer.processor.titleize} #{pay_customer.processor_id}"
    case pay_customer.processor
    when "braintree"
      payment_method = pay_customer.customer.payment_methods.find(&:default?)
      Pay::Braintree::PaymentMethod.sync(payment_method.token, object: payment_method) if payment_method
    when "stripe"
      payment_method_id = pay_customer.customer.invoice_settings.default_payment_method
      Pay::Stripe::PaymentMethod.sync(payment_method_id) if payment_method_id
    when "paddle"
      Pay::Paddle::PaymentMethod.sync(pay_customer: pay_customer)
    end
  rescue
    sleep 0.5
    try += 1
    (try <= retries) ? retry : raise
  end
end
