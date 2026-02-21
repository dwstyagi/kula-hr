Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # === Tenant subdomain routes ===
  constraints subdomain: /.+/ do
    devise_for :users

    namespace :admin do
      root "dashboard#index"
      resources :departments
      resources :designations
      resources :employees do
        collection do
          get :template
          get :export
        end
        member do
          post :resend_invite
        end
      end
      resources :imports, only: [ :new, :create ] do
        collection do
          get  :preview
          post :confirm
          get  :download_errors
        end
      end
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
  scope :platform_admin, module: "platform", as: "platform_admin" do
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    root "dashboard#index"
    resources :tenants, only: [ :index, :show, :edit, :update ] do
      member do
        patch :toggle_status
      end
    end
  end
end
