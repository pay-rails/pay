module Pay
  class PaymentsController < ApplicationController
    layout "pay/application"

    before_action :set_redirect_to

    def show
      @payment = Payment.from_id(params[:id])
    end

    private

    # Ensure the back parameter is a valid path
    # This safely handles XSS or external redirects
    def set_redirect_to
      @redirect_to = URI.parse(params[:back].to_s).path || root_path
    end
  end
end
