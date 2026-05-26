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

import PdcUiLoader from './pdc/pdc_ui_loader.es6';
import WorksWizardPolicy from './works_wizard_policy';
import WorksWizardReview from './works_wizard_review';
import EditGroupUtils from './edit_group_utils';
import MessageInput from '../vue_components/message_input.vue';
import { createApp } from 'vue';

const app = createApp({});

// If you are not running a full Vue application, just embedding the component into a static HTML,
// ruby web app, or similar: one way to bind your logic to the async-load-items-function prop is
// to add it to the vue application's globalProperties.
const createMyApp = () => {
  const myapp = createApp(app);
  // myapp.config.globalProperties.searchUsers = (query) => searchUsers(query);
  return myapp;
};

function loadVueComponents() {
  const elements = document.getElementsByClassName('vue-component');
  console.log(`Found ${elements.length} elements with class 'vue-component'`);
  for (let i = 0; i < elements.length; i += 1) {
    createMyApp()
      // .component('lux-badge', LuxBadge)
      .component('message-input', MessageInput)
      .mount(elements[i]);
  }
}

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
import.meta.glob('../channels/*.js');

// Load Rails JavaScript API
if (
  typeof window._rails_loaded === 'undefined' ||
  window._rails_loaded == null ||
  !window._rails_loaded
) {
  Rails.start();
}

// Turbolinks
Turbolinks.start();

// Integrate JavaScript API with Turbolinks
function ready() {
  loadVueComponents();
  const loader = new PdcUiLoader();
  loader.run();

  WorksWizardPolicy.bind('#agreement');
  WorksWizardReview.bind('#grant-button');

  // This should be moved into the Rails object
  if (typeof pdc !== 'undefined' && pdc != null && pdc) {
    const groupUtils = new EditGroupUtils(window.jQuery);
    groupUtils.bind(pdc);
  }
}

// Must run the javascript loader on every page even if turbolinks loads it
$(document).on('turbolinks:load', ready);
