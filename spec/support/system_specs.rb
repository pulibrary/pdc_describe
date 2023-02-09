# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by(:rack_test)
  end

  config.before(:each, type: :system, js: true) do
    if ENV["RUN_IN_BROWSER"]
      driven_by(:selenium_chrome)
    else
      driven_by(:selenium_chrome_headless)
    end

    # Make the screen larger so the save button is alway on screen. This avoids random `Element is not clickable` errors
    Capybara.page.driver.browser.manage.window.resize_to(2000, 2000)
  end
  config.before(:each, type: :system, js: true, in_browser: true) do
    driven_by(:selenium_chrome)

    # Make the screen larger so the save button is alway on screen. This avoids random `Element is not clickable` errors
    Capybara.page.driver.browser.manage.window.resize_to(2000, 2000)
  end
end
