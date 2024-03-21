scope 'evertimer' do
  get '/user_stats', to: 'evertimer#index', as: 'user_stats'
end
