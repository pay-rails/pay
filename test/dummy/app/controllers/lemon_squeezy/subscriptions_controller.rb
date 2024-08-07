class LemonSqueezy::SubscriptionsController < ApplicationController
    def index
      @subscriptions = Pay::Subscription.joins(:customer).where(pay_customers: {processor: :lemon_squeezy}).order(created_at: :desc)
    end

    def new
    end

    def create
      lemon_squeezy_service = LemonSqueezyService.new(ENV['LEMON_SQUEEZY_API_KEY'])
      result = lemon_squeezy_service.create_fake_payment(payment_params)
  
      if result['error']
        render json: { error: result['error'] }, status: :unprocessable_entity
      else
        render json: result, status: :ok
      end
    end

    private

    def payment_params
      params.require(:payment).permit(:amount, :currency, :source)
    end
end