Rails.application.routes.draw do
  get 'import/do'
  root 'pages#home'
  get 'about', to: 'pages#about'
  get 'import', to: 'import#do'
  post 'import', to: 'import#import'
  get 'map', to: 'monuments#map'
  
  get 'monuments', to: 'monuments#index'
  get 'show', to: 'monuments#show'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
