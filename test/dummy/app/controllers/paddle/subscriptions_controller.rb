class Paddle::SubscriptionsController < ApplicationController
  before_action :set_subscription, only: [:show, :edit, :update, :destroy, :cancel, :resume]

  def index
    @subscriptions = Pay::Subscription.joins(:customer).where(pay_customers: {processor: :paddle}).order(created_at: :desc)
  end

  def show
  end

  def new
    @payment_processor = current_user.set_payment_processor :paddle
    @payment_processor.customer unless @payment_processor.processor_id?
  end

  def create
    current_user.set_payment_processor params[:processor]
    current_user.payment_processor.payment_method_token = params[:card_token]
    subscription = current_user.payment_processor.subscribe(plan: params[:plan_id])
    redirect_to paddle_classic_subscription_path(subscription)
  rescue Pay::Error => e
    flash[:alert] = e.message
    redirect_to new_paddle_classic_subscription_path
  end

  def edit
  end

  def update
  end

  def destroy
    @subscription.cancel_now!
    redirect_to paddle_classic_subscription_path(@subscription)
  end

  def cancel
    @subscription.cancel
    redirect_to paddle_classic_subscription_path(@subscription)
  end

  def resume
    @subscription.resume
    redirect_to paddle_classic_subscription_path(@subscription)
  end

  private

  def set_subscription
    @subscription = Pay::Subscription.find(params[:id])
  end
end
