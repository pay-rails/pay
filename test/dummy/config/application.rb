require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require "pay"
require "pp"

module Dummy
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.active_job.queue_adapter = :test
    config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
  end
end
