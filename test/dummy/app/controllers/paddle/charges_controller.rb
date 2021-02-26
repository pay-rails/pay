class Paddle::ChargesController < ApplicationController
  before_action :set_charge, only: [:show, :refund]

  def index
    @charges = Pay::Charge.where(processor: :paddle).order(created_at: :desc)
  end

  def show
  end

  def new
  end

  def create
    current_user.processor = params[:processor]
    current_user.card_token = params[:card_token]
    charge = current_user.charge(params[:amount])
    redirect_to paddle_charge_path(charge)
  rescue Pay::Error => e
    flash[:alert] = e.message
    render :new
  end

  def refund
    @charge.refund!
  rescue Pay::Error => e
    flash[:alert] = e.message
  ensure
    redirect_to paddle_charge_path(@charge)
  end

  private

  def set_charge
    @charge = Pay::Charge.find(params[:id])
  end
end
