module Pay
  class ApplicationMailer < ActionMailer::Base
    def self.default_from_address
      Pay.support_email || ::ApplicationMailer.default_params[:from]
    end

    default from: default_from_address
    layout "mailer"
  end
end
