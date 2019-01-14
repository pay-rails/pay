require 'pay/stripe/api'
require 'pay/stripe/billable'
require 'pay/stripe/charge'
require 'pay/stripe/subscription'
require 'pay/stripe/webhooks'

Pay::Stripe::Api.set_api_keys

Pay.charge_model.include Pay::Stripe::Charge
Pay.subscription_model.include Pay::Stripe::Subscription
Pay.user_model.include Pay::Stripe::Billable
