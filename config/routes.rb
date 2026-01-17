Rails.application.routes.draw do
  get 'up' => 'rails/health#show'

  namespace :api do
    resources :sites, only: [] do
      resources :slugs, only: [:create]
    end

    resources :caddy, only: [] do
      collection do
        get :check_domain
      end
    end
  end

  resources :sites, except: [:show] do
    resources :posts
    resources :books, except: [:show], shallow: true do
      collection do
        get :search
      end
    end
    resources :pages do
      member do
        put :add_to_navigation
        delete :remove_from_navigation
      end
    end
    resources :deployment_targets, only: %i[index edit update] do
      member do
        post :deploy
      end
    end
    resources :social_media_links, only: %i[create destroy]
    resources :users, only: %i[index destroy], controller: 'site_users'
    resources :invitations, only: %i[new create edit update destroy], controller: 'user_invitations', shallow: true do
      member do
        post :resend
      end
    end

    get 'image/create'
    resources :images, only: %i[show create] do
      collection do
        post :from_url
      end
    end

    resources :unsplash_images, only: [] do
      collection do
        get :search
        post :create
      end
    end
  end

  resources :navigation_items, only: %i[create destroy] do
    member do
      patch :move_up
      patch :move_down
    end
  end

  root 'sites#index'

  get 'login', to: 'sessions#new', as: :login
  post 'login', to: 'sessions#create'
  get 'login/:token', to: 'sessions#show', as: :login_token
  delete 'logout', to: 'sessions#destroy', as: :logout

  mount GoodJob::Engine => 'good_job', constraints: SuperAdminConstraint.new
end
