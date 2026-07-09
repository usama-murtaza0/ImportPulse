source "https://rubygems.org"

ruby ">= 3.1.0"

gem "rails", "~> 7.1.3"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"

# Background processing
gem "sidekiq", "~> 7.2"

# Hotwire
gem "turbo-rails"
gem "sprockets-rails"
gem "importmap-rails"

# Ruby 3.4 extracts csv from stdlib
gem "csv"

gem "bootsnap", require: false

group :development, :test do
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails"
  gem "debug", platforms: %i[mri]
end
