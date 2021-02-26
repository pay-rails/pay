module Stripe
  class CheckoutsController < ApplicationController
    def show
      current_user.processor = :stripe
      current_user.customer

      @payment = current_user.payment_processor.checkout(mode: "payment", line_items: "price_1ILVZaKXBGcbgpbZQ26kgXWG")
      @subscription = current_user.payment_processor.checkout(mode: "subscription", line_items: "default")
      @setup = current_user.payment_processor.checkout(mode: "setup")
      @portal = current_user.payment_processor.billing_portal(return_url: "http://localhost:3000/stripe/checkout")
    end
  end
end
