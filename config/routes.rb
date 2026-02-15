Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # === Tenant subdomain routes ===
  constraints subdomain: /.+/ do
    devise_for :users

    namespace :admin do
      root "dashboard#index"
    end

    namespace :employee_portal, path: "portal" do
      root "dashboard#index"
    end

    root "admin/dashboard#index", as: :tenant_root
  end

  # === Root domain routes (no subdomain) ===
  root "home#index"
  get "signup", to: "signups#new"
  post "signup", to: "signups#create"

  # Platform admin
  namespace :platform_admin do
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    root "dashboard#index"
    resources :tenants, only: [:index, :show, :edit, :update] do
      member do
        patch :toggle_status
      end
    end
  end
end
