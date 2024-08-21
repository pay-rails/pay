module LemonSqueezy
  class SubscriptionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create] # For testing purposes only

    def index
      @subscriptions = Pay::Subscription.joins(:customer).where(pay_customers: {processor: :lemon_squeezy}).order(created_at: :desc)
    end

    def create
      current_user.set_payment_processor(params[:processor])
      current_user.payment_processor.payment_method_token = params[:card_token]
      
      subscription = current_user.payment_processor.subscribe(plan: params[:plan_id])
      
      if subscription.persisted?
        render json: { url: lemon_squeezy_subscriptions_path }, status: :ok
      else
        render json: { error: 'Failed to create subscription' }, status: :unprocessable_entity
      end

    rescue Pay::Error => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
