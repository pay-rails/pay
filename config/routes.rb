Rails.application.routes.draw do
  post '/webhooks/stripe',    to: 'stripe_event/webhook#event'
  post '/webhooks/braintree', to: 'pay/webhooks/braintree#create'
end
