class PaymentMethodsController < ApplicationController
  def show
    @payment_method = current_user.payment_processor&.default_payment_method
  end
end
