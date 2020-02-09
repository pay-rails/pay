# frozen_string_literal: true

Pay::Engine.routes.draw do
  resources :payments, only: [:show], module: :pay
  post "webhooks/stripe", to: "stripe_event/webhook#event"
  post "webhooks/braintree", to: "pay/webhooks/braintree#create"
end
