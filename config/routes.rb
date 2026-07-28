Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "editions#today"
  resources :editions, only: %i[index show], param: :publish_on
  get "editions/:publish_on/share.jpg", to: "edition_images#share", as: :edition_share_image
  get "editions/:publish_on/share.mp4", to: "edition_images#share_video", as: :edition_share_video
  get "editions/:publish_on/composite.jpg", to: "edition_images#composite", as: :edition_composite_image
  get "/s/:code", to: "share_links#show", as: :share_link
  get "/feed.xml", to: "feeds#show", as: :feed
  get "/about", to: "pages#about", as: :about
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
    resources :editions, only: %i[index show] do
      member do
        post :regenerate_share_video
        post :regenerate_variant
      end
    end
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
