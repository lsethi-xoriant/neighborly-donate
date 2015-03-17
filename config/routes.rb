require 'sidekiq/web'

Neighborly::Application.routes.draw do

  inexistent_pages = %i(projects/free
    projects/7-kc-streetcar-starter-line/video_embed
    projects/7-kc-streetcar-starter-line/embed
    projects/12-academie-lafayette-cherry-street-playground/video_embed
    projects/12-cherry-street-playground/embed
    projects/16-better-block-kc-making-grand-grand/embed
    projects/20-powell-street-skate-spot/video_embed
    projects/29-rockledge-dog-park/embed
    projects/29-rockledge-dog-park/video_embed
    projects/44-wish-upon-a-fountain/embed
    projects/50-better-block-kc-2013/embed
    projects/57/video_embed
    projects/6-sustain-kansas-city-b-cycle/video_embed
    projects/rivermarket-dogpark/video_embed
  )

  inexistent_pages.each do |url|
    get "/#{url}", to: redirect("/")
  end

  unless Rails.env.test?
    constraints NonValidSubdomainConstraint do
      get '/', to: redirect('https://neighborly.com')
      get '/*wildcard', to: redirect('https://neighborly.com/%{wildcard}')
    end
  end

  devise_for :users, path: '',
    path_names:  {
      sign_in:  :login,
      sign_out: :logout,
      sign_up:  :sign_up
    },
    controllers: {
      omniauth_callbacks: :omniauth_callbacks,
      sessions:           :sessions
    }


  devise_scope :user do
    post '/sign_up', to: 'devise/registrations#create', as: :sign_up
  end

  check_user_admin = lambda { |request| request.env["warden"].authenticate? and request.env['warden'].user.admin }

  # Mountable engines
  constraints check_user_admin do
    mount Sidekiq::Web => '/sidekiq'
  end

  mount Neighborly::Api::Engine => '/api/', as: :neighborly_api
  mount Neighborly::Dashboard::Engine => '/dashboard/', as: :neighborly_dashboard
  mount Neighborly::Balanced::Creditcard::Engine => '/balanced/creditcard/', as: :neighborly_balanced_creditcard
  mount Neighborly::Balanced::Bankaccount::Engine => '/balanced/bankaccount/', as: :neighborly_balanced_bankaccount
  mount Neighborly::Balanced::Engine => '/balanced/', as: :neighborly_balanced

  # Non production routes
  if Rails.env.development?
    resources :emails, only: [ :index, :show ]
  end

  # Channels
  constraints ChannelConstraint do
    namespace :channels, path: '' do
      get '/', to: 'profiles#show', as: :profile
      resources :channels_subscribers, only: [:index, :create, :destroy]

      namespace :admin do

        get '/', to: 'dashboard#index', as: :dashboard

        namespace :reports do
          resources :subscriber_reports, only: [ :index ]
        end

        resources :followers, only: [ :index ]

        resources :projects, only: [ :index, :update] do
          member do
            put 'launch'
            put 'reject'
            put 'push_to_draft'
            put 'approve'
          end
        end
      end

      resources :projects, only: [:new, :create]
      # NOTE We use index instead of create to subscribe comming back from auth via GET
      resource :channels_subscriber, only: [:show, :destroy], as: :subscriber
    end
  end

  mount Neighborly::Admin::Engine => '/admin/', as: :neighborly_admin

  # Root path should be after channel constraints
  root to: redirect('https://neighborly.com/thanks')

  # Static Pages
  get '/sitemap',               to: 'static#sitemap',             as: :sitemap
  get '/how-it-works', 
      "/faq", 
      "/terms", 
      "/privacy", 
      "/start", 
      '/learn',
    to: redirect('https://neighborly.com/thanks')

  # Only accessible on development
  if Rails.env.development?
    get "/base",                to: "static#base",              as: :base
  end

  get "/discover/(:state)(/near/:near)(/category/:category)(/tags/:tags)(/search/:search)", to: redirect('https://neighborly.com/thanks')

  resources :tags, only: [:index]

  namespace :reports do
    resources :contribution_reports_for_project_owners, only: [:index]
  end

  # Temporary
  get '/projects/neuse-river-greenway-benches-draft', to: redirect('/projects/neuse-river-greenway-benches')

  resources :projects, except: [ :destroy ] do
    resources :faqs, controller: 'projects/faqs', only: [ :index, :create, :destroy ]
    resources :terms, controller: 'projects/terms', only: [ :index, :create, :destroy ]
    resources :updates, controller: 'projects/updates', only: [ :index, :create, :destroy ]

    collection do
      get 'video'
    end

    member do
      get 'embed'
      get 'video_embed'
      get 'embed_panel'
      get 'comments'
      get 'reports'
      get 'budget'
      get 'success'
    end

    resources :rewards, except: :show do
      member do
        post 'sort'
      end
    end

    resources :contributions, controller: 'projects/contributions', except: :update do
      member do
        put 'credits_checkout'
      end
    end

    resources :matches, controller: 'projects/matches', except: %i(index update destroy)
  end

  scope :login, controller: :sessions do
    devise_scope :user do
      get   :set_new_user_email
      patch :confirm_new_user_email
    end
  end

  resources :users, path: 'neighbors' do
    resources :questions, controller: 'users/questions', only: [:new, :create]
    resources :projects, controller: 'users/projects', only: [ :index ]
    resources :contributions, controller: 'users/contributions', only: [:index] do
      member do
        get :request_refund
      end
    end

    resources :authorizations, controller: 'users/authorizations', only: [:destroy]
    resources :unsubscribes, only: [:create]
    member do
      get :settings
      get :credits
      get :payments
      get :edit
      put :update_email
      put :update_password
    end
  end

  get :contact, to: 'contacts#new'
  resources :contacts, only: [:create]

  resources :images, only: [:new, :create]

  namespace :markdown do
    resources :previewer, only: :create
  end

  get "/set_email" => "users#set_email", as: :set_email_users

  ### Redirects ###

  get "/users/:id", to: redirect('neighbors/%{id}')
  get '/projects/57/video_embed', to: redirect('projects/ideagarden/video_embed')
  get '/projects/:id/undefined', to: redirect('/projects/%{id}')
  get '/projects/:id/backers', to: redirect('/projects/%{id}')
  get '/projects/:id/reward_contact', to: redirect('/projects/%{id}')

  get '/2014/switching-to-balanced-and-cutting-our-fee', to: redirect('http://blog.neighbor.ly/news/switching-to-balanced-and-cutting-our-fee')

  get "/:id", to: redirect('projects/%{id}')
end
