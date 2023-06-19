/* eslint class-methods-use-this: ["error", {
  "exceptMethods": ["hasCreators", "validCreators"] }] */

import TableRow from './table_row.es6';

export default class EditRequiredFields {
  constructor() {
    this.required_tab = $('#v-pills-required-tab');
  }

  attach_validations() {
    // Client side validations before allowing user to create the dataset.
    $('#btn-create-new').on('click', this.validate_required.bind(this));
    if ($('#description') !== undefined) {
      $('#btn-submit').on('click', this.validate_required_step2.bind(this));
    }
  }

  validate_required() {
    const title = $('#title_main').val() || '';
    let status = true;

    $('#title-required-message').addClass('hidden');
    $('#creators-required-message').addClass('hidden');

    if (!this.hasCreators()) {
      this.openRequired();
      $('.creators-table-row input').focus();
      $('#creators-required-message').removeClass('hidden');
      status = false;
    } else if (!this.validCreators()) {
      status = false;
    }

    if (title.trim() === '') {
      this.openRequired();
      $('#title_main').focus();
      $('#title-required-message').removeClass('hidden');
      status = false;
    }

    return status;
  }

  validate_required_step2() {
    const description = $('#description').val() || '';
    let status = this.validate_required();
    $('#description-required-message').addClass('hidden');

    if (description.trim() === '') {
      if (status) {
        this.openRequired();
        $('#description').focus();
      }
      $('#description-required-message').removeClass('hidden');
      status = false;
    }
    return status;
  }

  // Returns true if there is at least one creator with information
  hasCreators() {
    let i;
    const rows = $('.creators-table-row');
    for (i = 0; i < rows.length; i += 1) {
      if (!((new TableRow(rows[i])).is_empty())) {
        return true;
      }
    }
    return false;
  }

  validCreators() {
    let i;
    let validCreators = true;
    const rows = $('.creators-table-row');
    for (i = 0; i < rows.length; i += 1) {
      const given = $(rows[i]).find('.given-entry-creator')[0];
      if (given.value === '') {
        $(rows[i]).find('.given-name-required-message').removeClass('hidden');
        validCreators = false;
      } else {
        $(rows[i]).find('.given-name-required-message').addClass('hidden');
      }
      const family = $(rows[i]).find('.family-entry-creator')[0];
      if (family.value === '') {
        $(rows[i]).find('.family-name-required-message').removeClass('hidden');
        validCreators = false;
      } else {
        $(rows[i]).find('.family-name-required-message').addClass('hidden');
      }
    }
    return validCreators;
  }

  openRequired() {
    if (this.required_tab.length > 0 && this.required_tab[0].className !== 'nav-link active') {
      this.required_tab.click();
    }
  }
}
