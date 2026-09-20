module Pay
  class PaymentsController < ApplicationController
    layout "pay/application"

    before_action :set_redirect_to

    # Intents on a Stripe Connect account are linked with ?stripe_account=acct_123
    def show
      @payment = Payment.from_id(params[:id], stripe_account: params[:stripe_account].presence)
    rescue ::Stripe::StripeError => e
      redirect_to root_path, alert: e.message
    end

    private

    # Ensure the back parameter is a valid path
    # This safely handles XSS or external redirects
    def set_redirect_to
      @redirect_to = URI.parse(params[:back].to_s).path.presence || root_path
    end
  end
end
