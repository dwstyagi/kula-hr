require "sidekiq/web"

Rails.application.routes.draw do
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Action Cable WebSocket
  mount ActionCable.server => "/cable"

  # === Tenant subdomain routes ===
  constraints subdomain: /.+/ do
    # Account suspended (public — no auth, skips suspension check)
    get "suspended", to: "suspended#show", as: :suspended

    # Self-service employee activation (public)
    get  "activate/:token", to: "employee_activations#new",    as: :employee_activation
    post "activate/:token", to: "employee_activations#create", as: :employee_activation_submit
    get  "activate/:token/sent", to: "employee_activations#sent", as: :employee_activation_sent

    # Self-registration invite link (public)
    get  "join/:token",      to: "employee_registrations#new",    as: :employee_registration
    post "join/:token",      to: "employee_registrations#create", as: :employee_registration_submit
    get  "join/:token/sent", to: "employee_registrations#sent",   as: :employee_registration_sent

    # Admin: generate/revoke activation link
    namespace :admin do
      resource :activation_link, only: [] do
        post :generate
        delete :revoke
      end
    end

    # Admin: generate/revoke invite link
    namespace :admin do
      resource :invite_link, only: [] do
        post   :generate
        delete :revoke
      end
    end

    devise_for :users, controllers: { sessions: "users/sessions" }

    namespace :admin do
      root "dashboard#index"
      resources :departments do
        collection { post :bulk_import }
      end
      resources :designations do
        collection { post :bulk_import }
      end
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
      resources :admin_users, only: [ :index, :new, :create, :destroy ]
      resources :employees do
        collection do
          get :template
          get :export
        end
        member do
          post :resend_invite
          patch :toggle_account_status
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
      resources :holidays do
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
      resources :leave_encashment_requests, only: [ :index ] do
        member do
          patch :approve
          patch :reject
        end
      end
      resources :comp_off_requests, only: [ :index ] do
        member do
          patch :approve
          patch :reject
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
      resource :company_profile, only: [ :show, :edit, :update ]
      resources :payroll_runs, only: [ :index, :new, :create, :show ] do
        member do
          post :process_payroll
          patch :submit_for_review
          patch :approve
          patch :reject
          patch :resubmit_for_review
          patch :reprocess
          patch :mark_paid
          get  :progress
          get  :download_payslips
          get  :bank_file
          get  :download_bank_file
        end
        resources :payslips, only: [ :index, :show, :edit, :update ], shallow: true do
          member do
            get :download
          end
        end
      end
      resources :reports, only: [ :index ] do
        collection do
          get :department_breakdown
          get :pf_report
          get :esi_report
          get :pt_challan
          get :ytd_earnings
          get :download_department_csv
          get :download_pf_ecr
          get :download_esi_csv
          get :download_pt_csv
          get :download_ytd_csv
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
      resources :leave_encashment_requests, only: [ :index, :create ]
      resources :comp_off_requests, only: [ :index, :new, :create ]
      resources :team_comp_off_requests, only: [ :index ] do
        member do
          patch :approve
          patch :reject
        end
      end
      resources :team_leave_requests, only: [ :index ] do
        member do
          patch :approve
          patch :reject
        end
      end
      resource :tax_declaration, only: [ :show, :edit, :update ] do
        patch :submit, on: :member
      end
      resources :payslips, only: [ :index, :show ] do
        member do
          get :download
        end
      end
      resource :profile, only: [ :show, :edit, :update ]
    end

    root "admin/dashboard#index", as: :tenant_root
  end

  # === Error pages ===
  match "/404", to: "errors#not_found", via: :all

  # === Root domain routes (no subdomain) ===
  root "home#index"
  get "privacy-policy", to: "home#privacy_policy", as: :privacy_policy
  get "terms-of-service", to: "home#terms_of_service", as: :terms_of_service
  get "signup", to: "signups#new"
  post "signup", to: "signups#create"
  get  "beta-guide",     to: "beta_guide#show",      as: :beta_guide
  post "beta-feedback",  to: "beta_feedbacks#create", as: :beta_feedback
  get "check_tenant", to: "home#check_tenant"
  get  "/contact", to: "contacts#new",    as: :contact
  post "/contact", to: "contacts#create"

  # Platform admin
  scope :platform_admin, module: "platform", as: "platform_admin" do
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    root "dashboard#index"
    resources :tenants, only: [ :index, :new, :create, :show, :edit, :update ] do
      member do
        patch :toggle_status
      end
    end
  end

  # Sidekiq Web UI — only accessible to authenticated Platform Admins
  PLATFORM_ADMIN_CONSTRAINT = lambda do |request|
    request.session[:platform_admin_id].present? &&
      PlatformAdmin.exists?(request.session[:platform_admin_id])
  end unless defined?(PLATFORM_ADMIN_CONSTRAINT)

  constraints(PLATFORM_ADMIN_CONSTRAINT) do
    mount Sidekiq::Web => "/platform_admin/sidekiq"
  end
end
