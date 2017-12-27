require 'pry'
require 'capybara/cucumber'
require 'capybara/poltergeist'
require 'selenium-webdriver'
require 'rspec/expectations'

Capybara.register_driver :safari do |app|
 Capybara::Selenium::Driver.new(app, :browser => :safari)
end

Capybara.configure do |config|
  config.run_server = false
  config.default_driver = :safari
end
