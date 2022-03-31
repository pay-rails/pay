module Pay
  class ApplicationMailer < ActionMailer::Base
    default from: Pay.support_email || ApplicationMailer.default_params[:from]
    layout "mailer"
  end
end
