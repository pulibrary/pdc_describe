# frozen_string_literal: true

require "factory_bot"
FactoryBot.find_definitions

require "webmock/rspec"

require "rspec-html-matchers"

# require 'rspec/matchers' # req by equivalent-xml custom matcher `be_equivalent_to`
require "equivalent-xml"

# Adds the ability to retry flaky tests.
# See https://github.com/NoRedInk/rspec-retry
require "rspec/retry"
require "selenium-webdriver"

# This file was generated by the `rails generate rspec:install` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# The generated `.rspec` file contains `--require spec_helper` which will cause
# this file to always be loaded, without a need to explicitly require it in any
# files.
#
# Given that it is always loaded, you are encouraged to keep this file as
# light-weight as possible. Requiring heavyweight dependencies from this file
# will add to the boot time of your test suite on EVERY test run, even for an
# individual file that may not need all of that loaded. Instead, consider making
# a separate helper file that requires the additional dependencies and performs
# the additional setup, and require it from the spec files that actually need
# it.
#

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  ##
  # Use WebMock to mock network connections. To temporarily re-enable network
  # connections within tests, toggle the WebMock.disable_net_connect! /
  # WebMock.enable_net_connect! setting.
  # Allow connections to local services / localhost
  allowed_sites = ["localhost", "chromedriver.storage.googleapis.com", "127.0.0.1", "github.com", "objects.githubusercontent.com"]

  # Add net_http_connect_on_start: true, to fix intermittent errors: "Failed to open TCP connection ... Too many open files"
  # https://stackoverflow.com/a/65946077
  # https://github.com/bblimke/webmock#connecting-on-nethttpstart
  WebMock.disable_net_connect!(allow: allowed_sites, net_http_connect_on_start: true)
  # WebMock.enable_net_connect!

  # FactoryBot
  config.include FactoryBot::Syntax::Methods

  config.include RSpecHtmlMatchers

  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
  # have no way to turn it off -- the option exists only for backwards
  # compatibility in RSpec 3). It causes shared context metadata to be
  # inherited by the metadata hash of host groups and examples, rather than
  # triggering implicit auto-inclusion in groups with matching metadata.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  ### Re-trying flaky system specs
  # show retry status in spec process
  config.verbose_retry = true
  # show exception that triggers a retry if verbose_retry is set to true
  config.display_try_failure_messages = true

  # run retry only on tests that use javascript and only in CI environment
  if ENV["CI"]
    config.around :each, :js do |ex|
      ex.run_with_retry retry: 3
    end
  end

  # callback to be run between retries
  config.retry_callback = proc do |ex|
    # run some additional clean up task - can be filtered by example metadata
    if ex.metadata[:js]
      Capybara.reset!
    end
  end

  # The settings below are suggested to provide a good initial experience
  # with RSpec, but feel free to customize to your heart's content.
  #   # This allows you to limit a spec run to individual examples or groups
  #   # you care about by tagging them with `:focus` metadata. When nothing
  #   # is tagged with `:focus`, all examples get run. RSpec also provides
  #   # aliases for `it`, `describe`, and `context` that include `:focus`
  #   # metadata: `fit`, `fdescribe` and `fcontext`, respectively.
  #   config.filter_run_when_matching :focus
  #
  #   # Allows RSpec to persist some state between runs in order to support
  #   # the `--only-failures` and `--next-failure` CLI options. We recommend
  #   # you configure your source control system to ignore this file.
  #   config.example_status_persistence_file_path = "spec/examples.txt"
  #
  #   # Limits the available syntax to the non-monkey patched syntax that is
  #   # recommended. For more details, see:
  #   #   - http://rspec.info/blog/2012/06/rspecs-new-expectation-syntax/
  #   #   - http://www.teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  #   #   - http://rspec.info/blog/2014/05/notable-changes-in-rspec-3/#zero-monkey-patching-mode
  #   config.disable_monkey_patching!
  #
  #   # Many RSpec users commonly either run the entire suite or an individual
  #   # file, and it's useful to allow more verbose output when running an
  #   # individual spec file.
  #   if config.files_to_run.one?
  #     # Use the documentation formatter for detailed output,
  #     # unless a formatter has already been configured
  #     # (e.g. via a command-line flag).
  #     config.default_formatter = "doc"
  #   end
  #
  #   # Print the 10 slowest examples and example groups at the
  #   # end of the spec run, to help surface which specs are running
  #   # particularly slow.
  #   config.profile_examples = 10
  #
  #   # Run specs in random order to surface order dependencies. If you find an
  #   # order dependency and want to debug it, you can fix the order by providing
  #   # the seed, which is printed after each run.
  #   #     --seed 1234
  config.order = :random
  #
  #   # Seed global randomization in this process using the `--seed` CLI option.
  #   # Setting this allows you to use `--seed` to deterministically reproduce
  #   # test failures related to randomization by passing the same `--seed` value
  #   # as the one that triggered the failure.
  #   Kernel.srand config.seed
end

# Silence deprecation warnings until upstream Capybara version is updated
# See https://github.com/teamcapybara/capybara/issues/2779
Selenium::WebDriver.logger.ignore(:clear_local_storage, :clear_session_storage)

# Exports to a file the data from a spec if ENV variable is set.
def export_spec_data(file_name, data)
  return unless ENV["DATA_MIGRATION"] == "true"
  export_path = "./tmp/data_migration"
  Dir.mkdir export_path unless File.exist?(export_path)
  File.write("#{export_path}/#{file_name}", data)
end
