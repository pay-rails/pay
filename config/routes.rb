# frozen_string_literal: true

Pay::Engine.routes.draw do
  resources :payments, only: [:show], module: :pay
  post "webhooks/stripe", to: "pay/webhooks/stripe#create" if defined? ::Stripe
  post "webhooks/braintree", to: "pay/webhooks/braintree#create" if defined? ::Braintree
  post "webhooks/paddle", to: "pay/webhooks/paddle#create" if defined? ::PaddlePay
end
