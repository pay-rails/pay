module LemonSqueezy
  class SubscriptionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create] # For testing purposes only

    def index
      @subscriptions = Pay::Subscription.joins(:customer).where(pay_customers: {processor: :lemon_squeezy}).order(created_at: :desc)
    end


    def create
      raise
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
      end
    end

    private

    def checkout_params
      params.require(:data).permit(
        attributes: [:redirect_url],
        relationships: [:store, :variant]
      )
    end
  end
end
