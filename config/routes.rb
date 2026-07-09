require "sidekiq/web"

Rails.application.routes.draw do
  root "imports#index"

  resources :imports, only: %i[index show create]

  # Sidekiq dashboard — in a real app this sits behind authentication.
  mount Sidekiq::Web => "/sidekiq" if Rails.env.development?
end
