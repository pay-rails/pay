require 'stripe_event'

Rails.application.routes.draw do
  mount StripeEvent::Engine, at: '/webhooks/stripe'
end
