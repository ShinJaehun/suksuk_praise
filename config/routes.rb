Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  # get "up" => "rails/health#show", as: :rails_health_check

  resources :users, only: [:show] do
    member do
      post :compliment
    end
  end

  # resources :classrooms do
  #   member do
  #     get :new_student
  #     post :add_student
  #     get :bulk_students
  #     post :create_bulk_students
      
  #     post :refresh_compliment_king
  #   end
  # end

  resources :classrooms do
    member { get :refresh_compliment_king }
    resources :students, controller: "classroom_students", only: [:new, :create] do
      collection do
        get :bulk_new
        post :bulk_create
      end
    end 
  end

  # Defines the root path route ("/")
  root "classrooms#index"
end
