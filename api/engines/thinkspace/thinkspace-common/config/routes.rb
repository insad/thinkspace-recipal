Thinkspace::Common::Engine.routes.draw do

	namespace :api do
		scope path: '/thinkspace/common/' do
      # Admin block needs to be first, otherwise it may collide with normal resources.
      # e.g. /users/select?ids=# would be interpreted as /users/:id with id: 'select' if this was not first.
      scope module: :admin do
        resources :spaces, only: [:update, :create] do
          member do
            get  :roster
            get  :invitations
            get  :teams
            get  :team_sets
            put  :invite
            post :import
            post :import_teams
            post :clone
          end
        end

        resources :users, only: [] do
          get :select, on: :collection
          member do
            put  :refresh
            post :switch
          end
        end

        resources :space_users, only: [:update] do
          put :resend, on: :member
          put :activate, on: :member
          put :inactivate, on: :member
        end

        resources :invitations, only: [:create, :destroy] do
          put :refresh, on: :member
          put :resend, on: :member
          get :fetch_state, on: :member
        end
      end

      # Non-admin
			resources :spaces, only: [:index, :show]

      resources :users, only: [:show, :create, :update] do
        collection do
          post :sign_in
          post :sign_out
          get  :stay_alive
          get  :validate
        end
        member do
          post :avatar
          put  :update_tos
          put  :add_key
          get  :list_keys
        end
      end

      resources :disciplines, only: [:index, :show] do
        collection do
          get :select
        end
      end

      resources :agreements, only: [:index, :show] do
        collection do
          get :select
          get :latest_for
        end
      end

      resources :password_resets, only: [:show, :create, :update]
      resources :components, only: [:show, :index] do
        collection do
          get :select
        end
      end

      concern :invalid, Totem::Core::Routes::Invalid.new(); concerns [:invalid]

		end
	end

end
