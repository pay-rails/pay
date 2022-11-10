module Pay
  class ApplicationMailer < ActionMailer::Base
    def from_address(name, email)
      return if email.blank?

      address = Mail::Address.new email
      address.display_name = name if name.present?
      address.format
    end

    default from: from_address(Pay.business_name, Pay.support_email) || ApplicationMailer.default_params[:from]
    layout "mailer"
  end
end
