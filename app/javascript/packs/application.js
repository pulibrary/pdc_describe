// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.

import Rails from "@rails/ujs"
import Turbolinks from "turbolinks"
import * as ActiveStorage from "@rails/activestorage"
import "channels"
// Provides @mention functionality in textboxes (adds to jQuery UI autocomplete)
import "./vendor/jquery-ui-triggeredAutocomplete"
import WorkForm from "./works/form"

Rails.start()
Turbolinks.start()
ActiveStorage.start()

$(document).ready( (event) => {

  $(".work-form").each( (index, element) => {
    const $element = $(element);
    const work = $element.data('work');
    const workForm = new WorkForm($element, work);
  });
});
