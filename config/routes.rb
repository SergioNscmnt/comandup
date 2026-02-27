require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users,
             skip: [:sessions, :registrations],
             path: "",
             path_names: { password: "recuperar-senha" },
             controllers: { passwords: "users/passwords" }
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  end

  resources :products, only: :index
  resources :combos, only: :index
  resources :promotions, only: :index
  get "mesa/:identifier", to: "table_sessions#show", as: :table_qr

  get "login", to: "sessions#new", as: :customer_login
  post "login", to: "sessions#create", as: :customer_session
  post "signup", to: "sessions#signup", as: :customer_signup
  get "login/google", to: "sessions#google_start", as: :customer_google_login
  get "login/google/callback", to: "sessions#google_callback", as: :customer_google_callback
  delete "logout", to: "sessions#destroy", as: :customer_logout
  resource :account, only: [:show, :update], path: "minha-conta", controller: "accounts"

  resource :cart, only: [:show, :update, :destroy] do
    get :delivery_quote
  end
  get "geo/suggestions", to: "geo#suggestions"

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

    resource :dashboard, only: :show, controller: "dashboards" do
      get :finance
      get :simulator
      get :alerts
    end
    resource :queue, only: :show, controller: "queue"
    resource :company_profile, only: [:edit, :update], controller: "company_profiles"
    resources :products, only: [:new, :create, :edit, :update, :destroy]
    resources :combos, only: [:new, :create]
    resources :promotions, only: [:new, :create]
    resources :categories, only: [:new, :create, :edit, :update] do
      collection do
        patch :reorder
      end
    end

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
