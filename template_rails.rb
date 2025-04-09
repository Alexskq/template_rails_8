run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# Gemfile
########################################
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    gem "devise"
    gem "simple_form"
    # Tailwind v4
    gem "tailwindcss-ruby"
    gem "tailwindcss-rails"
    ####
    gem "simple_form-tailwind", github: "Alexskq/simple_form-tailwind"

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
  <% if notice %>
    <div role="alert" class="alert alert-info">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        class="h-6 w-6 shrink-0 stroke-current">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
      <span><%= notice %></span>
    </div>
  <% end %>
  <% if alert %>
    <div role="alert" class="alert alert-error">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="h-6 w-6 shrink-0 stroke-current"
        fill="none"
        viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <span><%= alert %></span>
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

  old_link_to = <<~HTML
    <p>Unhappy? <%= link_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete %></p>
  HTML

  new_link_to = <<~HTML
    <p>Unhappy? <%= button_to "Cancel my account", registration_path(resource_name), data: { confirm: "Are you sure?" }, method: :delete %></p>
  HTML
  gsub_file("app/views/devise/registrations/edit.html.erb", old_link_to, new_link_to)

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

  # Tailwind install + npm daisyui
  ########################################
 
  # inject_into_file "config/tailwind.config.js", after: "content: [\n" do
  #   <<~JS
  #     \    './config/initializers/*.rb',
  #   JS
  # end
  # --------------------
  # Update DaisyUI
  # --------------------
   # À la place de: run "npm i -D daisyui@latest"
  # Utilisez cette version qui permet de choisir entre pnpm, npm ou yarn
  
  # Detect and use available package manager (preference: pnpm > npm > yarn)
  run <<~BASH
    if command -v pnpm &> /dev/null; then
      echo "Installing DaisyUI with pnpm..."
      pnpm add -D daisyui@latest
    elif command -v npm &> /dev/null; then
      echo "Installing DaisyUI with npm..."
      npm i -D daisyui@latest
    else
      echo "Installing DaisyUI with yarn..."
      yarn add -D daisyui@latest
    fi
  BASH
  inject_into_file "/app/assets/tailwind/application.css", after: "@import \"tailwindcss\" do\n" do
    <<~JS
      \    @plugin "daisyui";
    JS
  end
  # inject_into_file "config/tailwind.config.js", after: "plugins: [\n" do
  #   <<~JS
  #     \    require("daisyui"),
  #   JS
  # end

  # Heroku
  ########################################
  run "bundle lock --add-platform x86_64-linux"

  # Hook
  #########################################
  run "npm install --save-dev husky"
  run "npx husky init"
  remove_file ".husky/pre-commit", force: true
  create_file ".husky/pre-commit", <<-EOF
#!/bin/bash

rubocop -A || true
git add .
EOF
create_file ".husky/post-commit", <<-EOF
#!/bin/bash

rubocop || true
echo "\\nRun \\033[0;33mrubocop -A\\033[0m to auto-correct them."
EOF
  create_file ".husky/post-merge", <<-EOF
echo 'Installing Ruby dependencies...'
bundle install
echo 'Installing npm dependencies...'
npm install
echo 'Running database migrations...'
rails db:migrate
EOF

  # Git
  ########################################
  git add: "."
  git commit: "-m 'Initial commit made by Arnaud & Alex Wagoners' -n"
end
