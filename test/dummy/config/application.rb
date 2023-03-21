require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require "pay"

module Dummy
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.active_job.queue_adapter = :test
    config.action_mailer.default_url_options = {host: "localhost", port: 3000}

    # Remove warnings
    config.active_record.legacy_connection_handling = false if Rails.gem_version >= Gem::Version.new("6.1") && Rails.gem_version < Gem::Version.new("7.1.0.alpha")

    # Set the ActionMailer preview path to the gem test directory
    config.action_mailer.show_previews = true
    config.action_mailer.preview_path = Rails.root.join("../../test/mailers/previews")
  end
end
