module Pay
  class PaymentsController < ApplicationController
    layout "pay/application"

    # Intents on a Stripe Connect account are linked with ?stripe_account=acct_123
    # The back link only follows a same-host URL or a path, so it can't be used for an open redirect
    def show
      @payment = Payment.from_id(params[:id], stripe_account: params[:stripe_account].presence)
      @redirect_to = url_from(params[:back]) || root_path
    rescue ::Stripe::StripeError => e
      redirect_to root_path, alert: e.message
    end
  end
end
