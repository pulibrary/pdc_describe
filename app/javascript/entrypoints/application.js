/* eslint no-underscore-dangle: [ "error", { "allow": ["_rails_loaded"] } ] */
/* eslint no-console: "off" */

// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>
// Example: Import a stylesheet in app/frontend/index.css
// import '~/index.css'

import Rails from '@rails/ujs';
import Turbolinks from 'turbolinks';
// Provides @mention functionality in textboxes (adds to jQuery UI autocomplete)
import './vendor/jquery-ui-triggeredAutocomplete';

import PdcUiLoader from './pdc/pdc_ui_loader.es6';
import WorksWizardPolicy from './works_wizard_policy';

// If using a TypeScript entrypoint file:
//     <%= vite_typescript_tag 'application' %>
//
// If you want to use .jsx or .tsx, add the extension:
//     <%= vite_javascript_tag 'application.jsx' %>

// Example: Load Rails libraries in Vite.
//
// import * as Turbo from '@hotwired/turbo'
// Turbo.start()
//
// import ActiveStorage from '@rails/activestorage'
// ActiveStorage.start()
//
// Import all channels.
import.meta.globEager('../channels/*.js');

if (typeof (window._rails_loaded) === 'undefined' || window._rails_loaded == null || !window._rails_loaded) {
  Rails.start();
}
Turbolinks.start();

function ready() {
  const loader = new PdcUiLoader();
  loader.run();

  WorksWizardPolicy.bind('#agreement');
}

// Must run the javascript loader on every page even if turbolinks loads it
$(document).on('turbolinks:load', ready);
