module Pay
  class ApplicationMailer < ActionMailer::Base
    default from: from(Pay.business_name, Pay.support_email) || ApplicationMailer.default_params[:from]
    layout "mailer"

    def from(name, email)
      return if email.blank? 
      
      address = Mail::Address.new email
      address.display_name = name if name.present?
      address.format
    end
  end
end
