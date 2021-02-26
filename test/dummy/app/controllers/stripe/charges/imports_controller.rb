module Stripe
  class Charges::ImportsController < ApplicationController
    def new
    end

    def create
      object = find_stripe_object
      charge = Pay::Stripe::Webhooks::ChargeSucceeded.new.create_charge(User.first, object)
      redirect_to stripe_charge_path(charge)
    end

    private

    def find_stripe_object
      case params[:id]
      when /^ch_/
        Stripe::Charge.retrieve(params[:id])
      when /^pi_/
        Stripe::PaymentIntent.retrieve(params[:id]).charges.first
      end
    end
  end
end
