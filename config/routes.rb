# frozen_string_literal: true

Pay::Engine.routes.draw do
  resources :payments, only: [:show], module: :pay
  post "webhooks/stripe", to: "pay/webhooks/stripe#create" if Pay::Stripe.enabled?
  post "webhooks/braintree", to: "pay/webhooks/braintree#create" if Pay::Braintree.enabled?
  post "webhooks/paddle_billing", to: "pay/webhooks/paddle_billing#create" if Pay::PaddleBilling.enabled?
  post "webhooks/paddle_classic", to: "pay/webhooks/paddle_classic#create" if Pay::PaddleClassic.enabled?
  post "webhooks/lemon_squeezy", to: "pay/webhooks/lemon_squeezy#create" if Pay::LemonSqueezy.enabled?
end
