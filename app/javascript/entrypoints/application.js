// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>
// Example: Import a stylesheet in app/frontend/index.css
// import '~/index.css'

import Rails from '@rails/ujs';
import Turbolinks from 'turbolinks';
import ActiveStorage from '@rails/activestorage';
// Provides @mention functionality in textboxes (adds to jQuery UI autocomplete)
import './vendor/jquery-ui-triggeredAutocomplete';

import PdcUiLoader from './pdc/pdc_ui_loader.es6';

console.log('Vite ⚡️ Rails');

// If using a TypeScript entrypoint file:
//     <%= vite_typescript_tag 'application' %>
//
// If you want to use .jsx or .tsx, add the extension:
//     <%= vite_javascript_tag 'application.jsx' %>

console.log('Visit the guide for more information: ', 'https://vite-ruby.netlify.app/guide/rails');

// Example: Load Rails libraries in Vite.
//
// import * as Turbo from '@hotwired/turbo'
// Turbo.start()
//
// import ActiveStorage from '@rails/activestorage'
// ActiveStorage.start()
//
// Import all channels.
const channels = import.meta.globEager('../channels/*.js');

if (typeof (window._rails_loaded) === 'undefined' || window._rails_loaded == null || !window._rails_loaded) {
  Rails.start();
}
Turbolinks.start();
ActiveStorage.start();

const loader = new PdcUiLoader();
loader.run();
