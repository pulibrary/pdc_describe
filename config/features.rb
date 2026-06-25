# frozen_string_literal: true
Flipflop.configure do
  # Strategies will be used in the order listed here.
  strategy :active_record
  strategy :default

  # Other strategies:
  #
  # strategy :sequel
  # strategy :redis
  #
  # strategy :query_string
  # strategy :session
  #
  # strategy :my_strategy do |feature|
  #   # ... your custom code here; return true/false/nil.
  # end

  # Declare your features, e.g:
  #
  # feature :world_domination,
  #   default: true,
  #   description: "Take over the world."

  feature :migrate_pppl_dataset, default: false, description: "Display the Migrate the PPPL dataset option menu and route to the page."
  feature :migrate_prds_dataset, default: false, description: "Display the Migrate the PRDS dataset option menu and route to the page."
  feature :create_dataset, default: false, description: "Display the Create dataset option menu and route to the page."
end