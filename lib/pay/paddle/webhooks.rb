Dir[File.join(__dir__, "webhooks", "**", "*.rb")].sort.each { |file| require file }

Pay::Webhooks.configure do |events|
  events.subscribe "paddle.subscription_created", Pay::Paddle::Webhooks::SubscriptionCreated.new
  events.subscribe "paddle.subscription_updated", Pay::Paddle::Webhooks::SubscriptionUpdated.new
  events.subscribe "paddle.subscription_cancelled", Pay::Paddle::Webhooks::SubscriptionCancelled.new
  events.subscribe "paddle.subscription_payment_succeeded", Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new
  events.subscribe "paddle.subscription_payment_refunded", Pay::Paddle::Webhooks::SubscriptionPaymentRefunded.new
end
