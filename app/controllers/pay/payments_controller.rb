module Pay
  class PaymentsController < ApplicationController
    layout "pay/application"

    # Payment confirmation is Stripe only, and the stripe gem may not be loaded
    before_action { head :not_found unless Pay::Stripe.enabled? }

    # Intents on a Stripe Connect account are linked with ?stripe_account=acct_123
    # The back link only follows a same-host URL or a path, so it can't be used for an open redirect
    def show
      @payment = Payment.from_id(params[:id], stripe_account: params[:stripe_account].presence)
      @redirect_to = url_from(params[:back]) || root_path
    rescue Pay::Error => e
      redirect_to root_path, alert: e.message
    end
  end
end
