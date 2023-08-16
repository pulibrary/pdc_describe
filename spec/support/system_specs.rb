# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each, type: :system) do
    Webdrivers::Chromedriver.required_version = "114.0.5735.90"
    driven_by(:rack_test)
  end

  config.before(:each, type: :system, js: true) do
    if ENV["RUN_IN_BROWSER"]
      driven_by(:selenium)
    else
      driven_by(:selenium_headless)
    end

    # Make the screen larger so the save button is alway on screen. This avoids random `Element is not clickable` errors
    Capybara.page.driver.browser.manage.window.resize_to(2000, 2000)
  end
  config.before(:each, type: :system, js: true, in_browser: true) do
    driven_by(:selenium)

    # Make the screen larger so the save button is alway on screen. This avoids random `Element is not clickable` errors
    Capybara.page.driver.browser.manage.window.resize_to(2000, 2000)
  end
end
