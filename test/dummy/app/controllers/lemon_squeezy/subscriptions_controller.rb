module LemonSqueezy
  class SubscriptionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create] # For testing purposes only

    def index
      @subscriptions = Pay::LemonSqueezy::Subscription.joins(:customer).where(pay_customers: {processor: :lemon_squeezy}).order(created_at: :desc)
    end

    def show
      @subscription = Pay::LemonSqueezy::Subscription.find(params[:id])
    end

    def new
      current_user.add_payment_processor(:lemon_squeezy)
      #@checkout = ::LemonSqueezy::Checkout.create(store_id: Pay::LemonSqueezy.store_id, variant_id: 479603)
      @checkout = ::LemonSqueezy::Checkout.create(store_id: Pay::LemonSqueezy.store_id, variant_id: 482626, product_options: {redirect_url: sync_lemon_squeezy_charges_url + "?lemon_squeezy_order_id=[order_id]"})
      redirect_to @checkout.url, allow_other_host: true
    end

    def sync
      Pay.sync(params)
      redirect_to lemon_squeey
    end
  end
end
