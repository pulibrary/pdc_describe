/* eslint class-methods-use-this: ["error", { "exceptMethods": ["isEmptyRow"] }] */

export default class EditRequiredFields {
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
      $(`#${this.findEmptyCreator()}`).focus();
      $('#creators-required-message').removeClass('hidden');
      status = false;
    }

    if (title.trim() === '') {
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
      if (status) $('#description').focus();
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
      if (!this.isEmptyRow(rows[i].id)) {
        return true;
      }
    }
    return false;
  }

  // Returns true if the "user entered" textboxes for the row are empty.
  isEmptyRow(rowId) {
    let i; let textboxId; let value;
    const $textboxes = $(`#${rowId} > td > input`);
    for (i = 0; i < $textboxes.length; i += 1) {
      textboxId = $textboxes[i].id;
      if (textboxId.startsWith('orcid_') || textboxId.startsWith('given_name_') || textboxId.startsWith('family_name_')) {
        value = $(`#${textboxId}`).val().trim();
        if (value !== '') {
          return false;
        }
      }
    }
    return true;
  }

  // Returns the ID of the first row that has an empty creator (if any)
  findEmptyCreator() {
    let i;
    const rows = $('.creators-table-row');
    for (i = 0; i < rows.length; i += 1) {
      if (this.isEmptyRow(rows[i].id)) {
        return rows[i].id;
      }
    }
    return null;
  }
}
