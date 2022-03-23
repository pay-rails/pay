# frozen_string_literal: true

Pay::Engine.routes.draw do
  resources :payments, only: [:show], module: :pay
  post "webhooks/stripe", to: "pay/webhooks/stripe#create" if Pay::Stripe.enabled?
  post "webhooks/braintree", to: "pay/webhooks/braintree#create" if Pay::Braintree.enabled?
  post "webhooks/paddle", to: "pay/webhooks/paddle#create" if Pay::Paddle.enabled?
end
