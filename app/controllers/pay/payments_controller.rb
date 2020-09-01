module Pay
  class PaymentsController < ApplicationController
    def show
      @redirect_to = params[:back].presence || root_path
      @payment = Payment.from_id(params[:id])
    end
  end
end
