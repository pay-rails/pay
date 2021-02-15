Dir[File.join(__dir__, "webhooks", "**", "*.rb")].sort.each { |file| require file }

Pay::Webhooks.configure do |events|
  events.subscribe "braintree.subscription_canceled", Pay::Braintree::Webhooks::SubscriptionCanceled.new
  events.subscribe "braintree.subscription_charged_successfully", Pay::Braintree::Webhooks::SubscriptionChargedSuccessfully.new
  events.subscribe "braintree.subscription_charged_unsuccessfully", Pay::Braintree::Webhooks::SubscriptionChargedUnsuccessfully.new
  events.subscribe "braintree.subscription_expired", Pay::Braintree::Webhooks::SubscriptionExpired.new
  events.subscribe "braintree.subscription_trial_ended", Pay::Braintree::Webhooks::SubscriptionTrialEnded.new
  events.subscribe "braintree.subscription_went_active", Pay::Braintree::Webhooks::SubscriptionWentActive.new
  events.subscribe "braintree.subscription_went_past_due", Pay::Braintree::Webhooks::SubscriptionWentPastDue.new
end
