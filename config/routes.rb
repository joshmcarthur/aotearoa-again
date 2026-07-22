Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "editions#today"
  resources :editions, only: %i[index show], param: :publish_on
  get "/feed.xml", to: "feeds#show", as: :feed
  get "/subscribe", to: "pages#subscribe", as: :subscribe

  namespace :admin do
    root to: "candidates#index"
    resources :candidates, only: %i[index show] do
      member do
        post :approve
        post :reject
        post :regenerate
      end
    end
    resources :editions, only: %i[index]
    resources :models, only: %i[index] do
      member do
        patch :toggle_preferred
      end
      collection do
        post :refresh
      end
    end
  end
end
