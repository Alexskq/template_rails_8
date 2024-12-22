run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# Gemfile
########################################
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "devise"
    gem "simple_form"
    gem "tailwindcss-rails"
    gem "simple_form-tailwind"

  RUBY
end

inject_into_file "Gemfile", after: "group :development do\n" do
  <<~RUBY
  \  gem "rails_live_reload"
  RUBY
end

# Flashes
########################################
file "app/views/shared/_flashes.html.erb", <<~HTML
<% if alert %>
  <div id="alert" class="fixed z-50 bottom-10 right-10 flex items-center p-6 mb-4 text-red-800 rounded-lg bg-red-50 dark:bg-gray-800 dark:text-red-400" role="alert">
    <svg class="flex-shrink-0 w-4 h-4" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
      <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5ZM9.5 4a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM12 15H8a1 1 0 0 1 0-2h1v-3H8a1 1 0 0 1 0-2h2a1 1 0 0 1 1 1v4h1a1 1 0 0 1 0 2Z" />
    </svg>
    <span class="sr-only">Info</span>
    <div class="mx-3 text-base font-medium">
      <%= alert %>
    </div>
    <button type="button" class="ms-auto -mx-1.5 -my-1.5 bg-red-50 text-red-500 rounded-lg focus:ring-2 focus:ring-red-400 p-1.5 hover:bg-red-200 inline-flex items-center justify-center h-8 w-8 dark:bg-gray-800 dark:text-red-400 dark:hover:bg-gray-700" data-dismiss-target="#alert" aria-label="Close">
      <span class="sr-only">Close</span>
      <svg class="w-3 h-3" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 14 14">
        <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6" />
      </svg>
    </button>
  </div>
<% end %>
<% if notice %>
  <div id="notice" class="fixed z-50 bottom-10 right-10 flex items-center p-6 mb-4 text-green-800 rounded-lg bg-green-50 dark:bg-gray-800 dark:text-green-400" role="notice">
    <svg class="flex-shrink-0 w-4 h-4" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
      <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5ZM9.5 4a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM12 15H8a1 1 0 0 1 0-2h1v-3H8a1 1 0 0 1 0-2h2a1 1 0 0 1 1 1v4h1a1 1 0 0 1 0 2Z" />
    </svg>
    <span class="sr-only">Info</span>
    <div class="mx-3 text-base font-medium">
      <%= notice %>
    </div>
    <button type="button" class="ms-auto -mx-1.5 -my-1.5 bg-green-50 text-green-500 rounded-lg focus:ring-2 focus:ring-green-400 p-1.5 hover:bg-green-200 inline-flex items-center justify-center h-8 w-8 dark:bg-gray-800 dark:text-green-400 dark:hover:bg-gray-700" data-dismiss-target="#notice" aria-label="Close">
      <span class="sr-only">Close</span>
      <svg class="w-3 h-3" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 14 14">
        <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6" />
      </svg>
    </button>
  </div>
<% end %>
HTML


inject_into_file "app/views/layouts/application.html.erb", after: "<body>" do
  <<~HTML
    <%= render "shared/flashes" %>
  HTML
end



########################################
# After bundle
########################################
after_bundle do

  # Generators: db + simple form + pages controller
  ########################################
  rails_command "db:reset"
  generate("simple_form:install")
  generate("simple_form:tailwind:install")
  generate(:controller, "pages", "home", "--skip-routes")

  # Routes
  ########################################
  route 'root to: "pages#home"'

  # Gitignore
  ########################################
  append_file ".gitignore", <<~TXT
  # Ignore .env file containing credentials.
  .env*

  # Ignore Mac and Linux file system files
  *.swp
  .DS_Store
  TXT

  # Devise install + user
  ########################################
  generate("devise:install")
  generate("devise", "User")

  # Tailwind
  ########################################
  rails_command "tailwindcss:install"

  # Application controller
  ########################################
  run "rm app/controllers/application_controller.rb"
  file "app/controllers/application_controller.rb", <<~RUBY
  class ApplicationController < ActionController::Base
    before_action :authenticate_user!
  end
  RUBY

  # migrate + devise views
  ########################################
  rails_command "db:migrate"
  generate("devise:views")

  old_button_to = <<~HTML
    <div>Unhappy? <%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?", turbo_confirm: "Are you sure?" }, method: :delete %></div>
  HTML

  new_button_to = <<~HTML
    <div>Unhappy? <%= button_to "Cancel my account", registration_path(resource_name), class:"text-red-700", data: { turbo_confirm: "Are you sure?" }, method: :delete %></div>
  HTML
  gsub_file("app/views/devise/registrations/edit.html.erb", old_button_to, new_button_to)

  # Pages Controller
  ########################################
  run "rm app/controllers/pages_controller.rb"
  file "app/controllers/pages_controller.rb", <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Tailwind install + npm daisyui + flowbite
  ########################################
  run "npm i -D daisyui@latest"
  run "npm i flowbite"
  inject_into_file "config/tailwind.config.js", after: "content: [\n" do
    <<~JS
      \    './config/initializers/*.rb',
          './node_modules/flowbite/**/*.js',
    JS
  end

  inject_into_file "config/tailwind.config.js", after: "plugins: [\n" do
    <<~JS
      \    require("daisyui"),
          require('flowbite/plugin'),
    JS
  end

  append_file "config/importmap.rb", <<~RUBY
    pin "flowbite", to: "https://cdn.jsdelivr.net/npm/flowbite@2.5.2/dist/flowbite.turbo.min.js"
  RUBY

  append_file "app/javascript/application.js", <<~JS
    import 'flowbite'
  JS
  # Heroku
  ########################################
  run "bundle lock --add-platform x86_64-linux"

  # Git
  ########################################
  git :init
  git add: "."
  git commit: "-m 'Initial commit made by Arnaud & Alex Wagoners' -q"
  lines = MESSAGE.split("\n")
  lines.each do |line|
    puts line.center(`tput cols`.to_i)
  end
end




























MESSAGE = <<~ASCII
\e[32m
DDDDDDDDDDDDD             OOOOOOOOO     NNNNNNNN        NNNNNNNNEEEEEEEEEEEEEEEEEEEEEE      !!!‎
D::::::::::::DDD        OO:::::::::OO   N:::::::N       N::::::NE::::::::::::::::::::E     !!:!!
D:::::::::::::::DD    OO:::::::::::::OO N::::::::N      N::::::NE::::::::::::::::::::E     !:::!
DDD:::::DDDDD:::::D  O:::::::OOO:::::::ON:::::::::N     N::::::NEE::::::EEEEEEEEE::::E     !:::!
  D:::::D    D:::::D O::::::O   O::::::ON::::::::::N    N::::::N  E:::::E       EEEEEE     !:::!
  D:::::D     D:::::DO:::::O     O:::::ON:::::::::::N   N::::::N  E:::::E                  !:::!
  D:::::D     D:::::DO:::::O     O:::::ON:::::::N::::N  N::::::N  E::::::EEEEEEEEEE        !:::!
  D:::::D     D:::::DO:::::O     O:::::ON::::::N N::::N N::::::N  E:::::::::::::::E        !:::!
  D:::::D     D:::::DO:::::O     O:::::ON::::::N  N::::N:::::::N  E:::::::::::::::E        !:::!
  D:::::D     D:::::DO:::::O     O:::::ON::::::N   N:::::::::::N  E::::::EEEEEEEEEE        !:::!
  D:::::D     D:::::DO:::::O     O:::::ON::::::N    N::::::::::N  E:::::E                  !!:!!
  D:::::D    D:::::D O::::::O   O::::::ON::::::N     N:::::::::N  E:::::E       EEEEEE      !!!‎
DDD:::::DDDDD:::::D  O:::::::OOO:::::::ON::::::N      N::::::::NEE::::::EEEEEEEE:::::E       ‎
D:::::::::::::::DD    OO:::::::::::::OO N::::::N       N:::::::NE::::::::::::::::::::E      !!!‎
D::::::::::::DDD        OO:::::::::OO   N::::::N        N::::::NE::::::::::::::::::::E     !!:!!
DDDDDDDDDDDDD             OOOOOOOOO     NNNNNNNN         NNNNNNNEEEEEEEEEEEEEEEEEEEEEE      !!! ‎
\e[0m
ASCII
