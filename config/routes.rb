Rails.application.routes.draw do
  post '/webhooks/stripe', to: 'stripe_event/webhook#event'
end
