web: bundle exec puma -C config/puma.rb
migrate: bundle exec rake db:migrate
worker: bundle exec sidekiq -e ${RAILS_ENV:-production}
console: bundle exec rails console
