# Load DSL and set up stages
require "capistrano/setup"

# Include default deployment tasks
require "capistrano/deploy"

# cap install
# bundle lock --add-platform x86_64-linux

# Load the SCM plugin appropriate to your project:
#
# require "capistrano/scm/hg"
# install_plugin Capistrano::SCM::Hg
# or
# require "capistrano/scm/svn"
# install_plugin Capistrano::SCM::Svn
# or
require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git

require "capistrano/bundler"
require "capistrano/rails"
require 'capistrano/rails/assets'
require 'capistrano/rails/migrations'

require "capistrano/rvm"
require 'capistrano/puma'
install_plugin Capistrano::Puma
# cap production puma:config
install_plugin Capistrano::Puma::Systemd
# cap production puma:systemd:config puma:systemd:enable
install_plugin Capistrano::Puma::Nginx
# cap production puma:nginx_config
# mkdir apps/mysite/shared/tmp/sockets

require 'capistrano/yarn'

require 'capistrano/sidekiq'
install_plugin Capistrano::Sidekiq  # Default sidekiq tasks
# Then select your service manager
install_plugin Capistrano::Sidekiq::Systemd

# cap production sidekiq:install

# su postgres
# cd
#createdb mysite_production
# psql
# create user rails with password 'mypassword';
# grant all privileges on database mysite_production to rails;
# exit # exit psql shell
# exit # back to root user

# cap lets_encrypt:register            # Register a Let's encrypt account
# cap lets_encrypt:check_certificate   # Check for validity of certificates
# cap lets_encrypt:authorize           # Authorize a domain using ACME protocol
# cap lets_encrypt:cert                # Create certificates and private keys

# Include tasks from other gems included in your Gemfile
#
# For documentation on these, see for example:
#
#   https://github.com/capistrano/rvm
#   https://github.com/capistrano/rbenv
#   https://github.com/capistrano/chruby
#   https://github.com/capistrano/bundler
#   https://github.com/capistrano/rails
#   https://github.com/capistrano/passenger
#
# require "capistrano/rvm"
# require "capistrano/rbenv"
# require "capistrano/chruby"
# require "capistrano/bundler"
# require "capistrano/rails/assets"
# require "capistrano/rails/migrations"
# require "capistrano/passenger"

# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }
