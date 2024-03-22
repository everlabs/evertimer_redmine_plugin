scope 'evertimer' do
  get '/user_stats', to: 'evertimer_user_stats#index', as: 'user_stats'
end
