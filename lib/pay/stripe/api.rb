env         = Rails.env.to_sym
secrets     = Rails.application.secrets
credentials = Rails.application.credentials

Stripe.api_key = secrets.dig(env, :stripe, :private_key) || credentials.dig(env, :stripe, :private_key) || ENV["STRIPE_PRIVATE_KEY"]
