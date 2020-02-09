module Pay
  class PaymentsController < ApplicationController
    def show
      @payment = Payment.from_id(params[:id])
    end
  end
end
