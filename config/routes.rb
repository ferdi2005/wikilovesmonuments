require 'sidekiq/web'
require 'sidekiq/cron/web'
Rails.application.routes.draw do
  get 'games/imagematch'
  get 'games/categorymatch'
  get 'games/articlematch'
  post 'games/imagematch', to: 'games#imagematch_save'
  post 'games/categorymatch', to: 'games#categorymatch_save'

  get 'monuments/nophoto_endpoint'

  get "start_login", to: 'authentication#start'
  get 'success', to: "authentication#success"
  get 'auth/failure', to: "authentication#failure"
  get "auth/mediawiki/callback", to: "authentication#process_data"

  get 'towns/search'
  get 'import/do'
  root 'pages#home'
  get 'about', to: 'pages#about'
  get 'import', to: 'import#do'
  post 'import', to: 'import#import'
  get 'map', to: 'monuments#map'

  get 'monuments', to: 'monuments#index'
  get 'address', to: 'monuments#address'
  get 'show', to: 'monuments#show'
  get 'show_by_wlmid', to: 'monuments#show_by_wlmid'
  get 'show_by_wikidata', to: 'monuments#show_by_wikidata'
  get 'namesearch', to: 'monuments#namesearch'
  get 'inscadenza', to: 'monuments#inscadenza'
  get 'nextid', to: "monuments#nextid"
  get 'findnextid', to: "monuments#findnextid"

  get 'doppioni', to: "monuments#doppioni"

  get 'api', to: "pages#api"
  # numerics stats

    get 'nophoto', to: 'numerics#nophoto'
    get 'nophotograph', to: 'numerics#nophotograph'

    # concorsi-locali stat
    get 'allregionscount', to: 'numerics#allregionscount'
    get 'allregionsdifference', to: 'numerics#allregionsdifference'

    get 'numerics-monuments', to: 'numerics#monuments'

    mount Sidekiq::Web => '/secret-sidekiq'


  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
