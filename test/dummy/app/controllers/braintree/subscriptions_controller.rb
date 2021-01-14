class Braintree::SubscriptionsController < ApplicationController
  before_action :set_subscription, only: [:show, :edit, :update, :destroy, :cancel, :resume]

  def index
    @subscriptions = Pay::Subscription.where(processor: :braintree).order(created_at: :desc)
  end

  def show
  end

  def new
  end

  def create
    current_user.processor = params[:processor]
    current_user.card_token = params[:card_token]
    subscription = current_user.subscribe(plan: params[:plan_id])
    redirect_to braintree_subscription_path(subscription)
  rescue Pay::Error => e
    flash[:alert] = e.message
    redirect_to new_braintree_subscription_path
  end

  def edit
  end

  def update
  end

  def destroy
    @subscription.cancel_now!
    redirect_to braintree_subscription_path(@subscription)
  end

  def cancel
    @subscription.cancel
    redirect_to braintree_subscription_path(@subscription)
  end

  def resume
    @subscription.resume
    redirect_to braintree_subscription_path(@subscription)
  end

  private

  def set_subscription
    @subscription = Pay::Subscription.where(processor: :braintree).find(params[:id])
  end
end
