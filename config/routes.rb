require "sidekiq/web"

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  end

  resources :products, only: :index
  resources :combos, only: :index
  resources :promotions, only: :index

  get "login", to: "sessions#new", as: :customer_login
  post "login/google", to: "sessions#create_google", as: :customer_google_login
  delete "logout", to: "sessions#destroy", as: :customer_logout

  resource :cart, only: [:show, :update, :destroy]

  resources :orders, only: [:index, :create, :show] do
    member do
      post :cancel
    end

    resource :payment, only: [:create, :show], controller: "payments"
  end

  namespace :admin do
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resource :queue, only: :show, controller: "queue"

    resources :orders, only: [] do
      member do
        post :start_production
        post :finish
        post :mark_ready
        post :mark_delivered
      end
    end
  end

  namespace :webhooks do
    resources :payments, only: :create
  end

  root "home#index"
end
