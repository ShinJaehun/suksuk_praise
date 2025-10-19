Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  # get "up" => "rails/health#show", as: :rails_health_check

  # resources :users, only: [:show] do
  #   member do
  #     post :compliment
  #   end
  # end

  resources :users, only: [:show]

  resources :classrooms do
    member { post :refresh_compliment_king }
    resources :students, controller: "classroom_students", only: [:new, :create] do
      collection do
        get :bulk_new
        post :bulk_create
      end
    end

    # /classrooms/:classroom_id/users/:id
    resources :users, only: [:show], controller: "users"  

    # RESTful 하게 칭찬은 교실 리소스 하위에 생성
    resources :compliments, only: [:create]
  end

  # 쿠폰 발급(교실에서 실행) — ClassroomsController#draw_coupon
  post "/classrooms/:id/draw_coupon",
       to: "classrooms#draw_coupon",
       as: :draw_coupon_classroom

  # 쿠폰 사용(교사가 학생 상세에서 실행) — UserCouponsController#use
  post "/users/:user_id/coupons/:id/use",
       to: "user_coupons#use",
       as: :use_user_coupon

  # 본인 쿠폰 목록
  get  "/users/:user_id/coupons",      to: "user_coupons#index", as: :user_coupons

  # Defines the root path route ("/")
  root "classrooms#index"

  resources :coupon_templates do
    member do
      post :adopt   # 라이브러리(=admin 소유) → 교사 개인 복제
      patch :toggle_active
    end
    collection do
      get :library # 탭 분리 없이 index에서 파라미터로 토글한다면 생략 가능
    end
  end

  namespace :admin do
    resources :coupon_events, only: :index
    resources :coupon_templates, except: [:show]
  end

end
