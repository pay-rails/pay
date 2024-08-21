module LemonSqueezy
  class ChargesController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create] # For testing purposes only

    def index
      @charges = Pay::LemonSqueezy::Charge.order(created_at: :desc)
    end

    def show
      @charge = Pay::LemonSqueezy::Charge.find(params[:id])
    end

    def new
      current_user.add_payment_processor(:lemon_squeezy)
      @checkout = ::LemonSqueezy::Checkout.create(store_id: Pay::LemonSqueezy.store_id, variant_id: 145832)
      redirect_to @checkout.url, allow_other_host: true
    end

    def sync
      Pay.sync(params)
      redirect_to lemon_squeezy_charges_path
    end
  end
end

