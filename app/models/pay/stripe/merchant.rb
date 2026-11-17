module Pay
  module Stripe
    class Merchant < Pay::Merchant
      def create_account(**options)
        stripe_account = Pay::Stripe.client.v1.accounts.create(options)
        update(processor_id: stripe_account.id)
        stripe_account
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def account
        Pay::Stripe.client.v1.accounts.retrieve(processor_id)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def account_link(refresh_url:, return_url:, type: "account_onboarding", **options)
        Pay::Stripe.client.v1.account_links.create({
          account: processor_id,
          refresh_url: refresh_url,
          return_url: return_url,
          type: type
        }.merge(options))
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # A single-use login link for Express accounts to access their Stripe dashboard
      def login_link(**options)
        Pay::Stripe.client.v1.accounts.login_links.create(processor_id, options)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Transfer money from the platform to this connected account
      # https://stripe.com/docs/connect/charges-transfers#transfer-availability
      def transfer(amount:, currency: "usd", **options)
        Pay::Stripe.client.v1.transfers.create({
          amount: amount,
          currency: currency,
          destination: processor_id
        }.merge(options))
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_stripe_merchant, Pay::Stripe::Merchant
