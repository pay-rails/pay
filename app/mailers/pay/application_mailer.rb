module Pay
  class ApplicationMailer < ActionMailer::Base
    default from: Pay.support_email
    layout "mailer"
  end
end
