module Stripe
  class PaymentMethodsController < ApplicationController
    def edit
      @setup_intent = ::Stripe::SetupIntent.create
    end

    def update
      current_user.set_payment_processor params[:processor]
      current_user.payment_processor.update_payment_method(params[:card_token])
      redirect_to payment_method_path
    end
  end
end
