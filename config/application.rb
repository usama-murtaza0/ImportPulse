require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_cable/engine"

Bundler.require(*Rails.groups)

require "csv"

module ImportPulse
  class Application < Rails::Application
    config.load_defaults 7.1

    config.autoload_lib(ignore: %w[assets tasks])

    # Sidekiq is the queue backend for anything that goes through ActiveJob,
    # though the import pipeline enqueues Sidekiq jobs directly.
    config.active_job.queue_adapter = :sidekiq
  end
end
