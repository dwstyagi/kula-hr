require "sidekiq/web"

Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Action Cable WebSocket
  mount ActionCable.server => "/cable"

  # === Tenant subdomain routes ===
  constraints subdomain: /.+/ do
    devise_for :users, controllers: { sessions: "users/sessions" }

    namespace :admin do
      root "dashboard#index"
      resources :departments
      resources :designations
      resources :salary_components do
        member do
          patch :toggle_active
        end
      end
      resources :salary_structures do
        member do
          patch :toggle_active
          post :add_component
          delete :remove_component
        end
      end
      resources :employees do
        collection do
          get :template
          get :export
        end
        member do
          post :resend_invite
          get :assign_salary
          post :assign_salary, action: :create_salary
          get :revise_salary
          post :revise_salary, action: :create_revision
        end
      end
      resources :leave_types do
        member do
          patch :toggle_active
        end
      end
      resources :leave_requests, only: [ :index ] do
        member do
          patch :approve
          patch :reject
          patch :cancel
        end
      end
      resources :attendance_summaries, only: [ :index, :show, :edit, :update ] do
        collection do
          post :generate
          patch :lock_month
          get  :download_template
          post :upload_template
        end
      end
      resource :payroll_setting, only: [ :show, :edit, :update ]
      resources :payroll_runs, only: [ :index, :new, :create, :show ] do
        member do
          post :process_payroll
          patch :submit_for_review
          patch :approve
          patch :reject
          patch :reprocess
          patch :mark_paid
          get  :progress
        end
      end
      get "salary_breakup", to: "salary_breakup#show"
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
      resources :leave_requests, only: [ :index, :new, :create ] do
        member do
          patch :cancel
        end
      end
      resource :tax_declaration, only: [ :show, :edit, :update ] do
        patch :submit, on: :member
      end
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

  # Sidekiq Web UI — only accessible to authenticated Platform Admins
  PLATFORM_ADMIN_CONSTRAINT = lambda do |request|
    request.session[:platform_admin_id].present? &&
      PlatformAdmin.exists?(request.session[:platform_admin_id])
  end

  constraints(PLATFORM_ADMIN_CONSTRAINT) do
    mount Sidekiq::Web => "/platform_admin/sidekiq"
  end
end
