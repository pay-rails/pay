<<<<<<< Updated upstream
module LemonSqueezy
  class SubscriptionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create] # For testing purposes only

    def create
      Rails.logger.info "Reached create action"
      raise 'Test exception'
      begin
        lemon_squeezy_service = LemonSqueezyService.new(ENV['LEMONSQUEEZY_API_KEY'])
        result = lemon_squeezy_service.create_checkout_session(checkout_params)

        if result[:success]
          render json: { checkout_url: result[:checkout_url] }, status: :ok
        else
          render json: { error: result[:error] }, status: :unprocessable_entity
        end

      rescue StandardError => e
        render json: { error: e.message }, status: :internal_server_error
=======
class LemonSqueezy::SubscriptionsController < ApplicationController
    def index
      @subscriptions = Pay::Subscription.joins(:customer).where(pay_customers: {processor: :lemon_squeezy}).order(created_at: :desc)
    end

    def new
<<<<<<< Updated upstream
    end
=======
    endg
>>>>>>> Stashed changes

    def create
      lemon_squeezy_service = LemonSqueezyService.new(ENV['LEMON_SQUEEZY_API_KEY'])
      result = lemon_squeezy_service.create_fake_payment(payment_params)
  
      if result['error']
        render json: { error: result['error'] }, status: :unprocessable_entity
      else
        render json: result, status: :ok
>>>>>>> Stashed changes
      end
    end

    private

<<<<<<< Updated upstream
    def checkout_params
      params.require(:data).permit(
        attributes: [:redirect_url],
        relationships: [:store, :variant]
      )
    end
  end
end
=======
    def payment_params
      params.require(:payment).permit(:amount, :currency, :source)
    end
end
>>>>>>> Stashed changes
