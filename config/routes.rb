Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }
  devise_scope :user do
    get "/account/password/edit", to: "users/registrations#edit_password", as: :edit_account_password
    patch "/account/password", to: "users/registrations#update_password", as: :account_password
  end

  get "/student_login", to: "student_sessions#new", as: :new_student_session
  delete "/student_logout", to: "student_sessions#destroy", as: :destroy_student_session
  get "/student_pin/edit", to: "student_pins#edit", as: :edit_student_pin
  patch "/student_pin", to: "student_pins#update", as: :student_pin
  get "/c/:student_login_token/login", to: "student_sessions#new", as: :public_student_login
  post "/c/:student_login_token/login", to: "student_sessions#create"
  get "/dashboard", to: "dashboards#show", as: :dashboard
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  # get "up" => "rails/health#show", as: :rails_health_check

  # resources :users, only: [:show] do
  #   member do
  #     post :compliment
  #   end
  # end

  resources :users, only: [:show] do
    resources :messages, only: [:create], controller: "user_messages"
  end

  resources :classrooms do
    resource :members, only: :show, module: :classrooms
    get "members/students/names/edit",
      to: "classrooms/members#edit_student_names",
      as: :edit_member_student_names
    patch "members/students/name",
      to: "classrooms/members#update_student_names",
      as: :member_student_names
    get "members/students/pin/edit",
      to: "classrooms/members#edit_student_pin",
      as: :edit_member_student_pin
    patch "members/students/pin",
      to: "classrooms/members#update_student_pin",
      as: :member_student_pin

    member do
      post :refresh_compliment_king
      get :student_login_info
      get :student_login_qr
      get "student_login_qr/download", to: "classrooms#download_student_login_qr", as: :download_student_login_qr
      patch :regenerate_student_login_token
    end

    resources :students, controller: "classroom_students", only: [:new, :create, :show, :edit, :update, :destroy] do
      resources :messages, only: [:index, :create], controller: "classroom_student_messages"
      resources :coupons, only: :create, controller: "user_coupons"
      collection do
        get :bulk_new
        post :bulk_preview
        post :bulk_create
      end
      member do
        get :activity
        get :dashboard
        get :coupon_assignment
        patch :deactivate
        patch :reactivate
      end
    end

    # RESTful 하게 칭찬은 교실 리소스 하위에 생성
    resources :compliments, only: [:new, :create]
  end

  get "/compliments", to: redirect { |_params, request|
    query_string = request.query_string.presence
    "/compliment_events#{query_string ? "?#{query_string}" : ""}"
  }
  get "/compliment_presets", to: redirect { |_params, request|
    query_string = request.query_string.presence
    "/compliment_templates#{query_string ? "?#{query_string}" : ""}"
  }
  resources :compliment_events, only: :index
  resources :compliment_templates, except: %i[show new]

  resources :schools, only: %i[index show edit update] do
    resources :teachers, only: %i[index new create edit update], module: :schools
    resources :school_closures, except: %i[index show]
  end

  # 쿠폰 발급(교실에서 실행) — ClassroomsController#draw_coupon
  post "/classrooms/:id/draw_coupon",
       to: "classrooms#draw_coupon",
       as: :draw_coupon_classroom

  # 쿠폰 사용(교사가 학생 상세에서 실행) — UserCouponsController#use
  post "/users/:user_id/coupons/:id/use",
       to: "user_coupons#use",
       as: :use_user_coupon

  post "/user_coupons/:id/reveal_issue",
       to: "user_coupons#reveal_issue",
       as: :reveal_issued_user_coupon

  post "/users/:user_id/coupons/:user_coupon_id/use_request",
       to: "coupon_use_requests#create",
       as: :request_user_coupon_use

  patch "/coupon_use_requests/:id/approve",
        to: "coupon_use_requests#approve",
        as: :approve_coupon_use_request

  # 본인 쿠폰 목록
  get  "/users/:user_id/coupons",      to: "user_coupons#index", as: :user_coupons

  # Defines the root path route ("/")
  root "home#index"

  resources :coupon_templates do
    member do
      post :adopt   # 라이브러리(=admin 소유) → 교사 개인 복제
      patch :toggle_active
      patch :bump_weight
      delete :remove_image
    end
    collection do
      post :rebalance_personal
      post :rebalance_library
      post :adopt_all_from_library
    end
  end

  # CouponEvent logs (teacher/admin unified)
  resources :coupon_events, only: [:index]

  namespace :admin do
    root to: redirect("/classrooms")

    resources :teachers, only: [:index, :new, :create, :edit, :update]
    resources :public_holidays, only: [] do
      post :sync, on: :collection
    end
    resources :schools, only: %i[new create edit update] do
      resources :school_managers, only: :create, path: :managers
      delete "managers/:user_id", to: "school_managers#destroy", as: :manager
    end

    resources :coupon_templates, except: [:show]
  end

end
