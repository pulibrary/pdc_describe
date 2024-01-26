/* eslint class-methods-use-this: ["error", {
  "exceptMethods": ["create_new_row", "delete_row", "find_empty_row",
  "setup_auto_complete_for_row"] }] */

import TableRow from './table_row.es6';

// Generic Actions to add and remove rows from a table
export default class EditTableActions {
  constructor() {
    this.orcid = $('#user_orcid').val();
    this.givenName = $('#user_given_name').val();
    this.familyName = $('#user_family_name').val();
  }

  attach_actions(tableId) {
    $('.btn-add-row').on('click', (event) => {
      this.create_new_row(event.target);
      return false;
    });

    $('.btn-add-user-creator').on('click', (event) => {
      this.create_user_row(event.target);
      const button = event.target;
      button.disabled = true;
      return false;
    });

    // Using $(document).on here so that the newly added rows will also pick up the event
    $(document).on('click', '.btn-del-row', (event) => {
      this.delete_row(event.target);
      return false;
    });

    // Attach the auto complete feature to the existing rows on the table
    const rows = $(`#${tableId} > tbody > tr`);
    for (let i = 0; i < rows.length; i += 1) {
      const $row = $(rows[i]);
      this.setup_auto_complete_for_row($row);
    }
  }

  create_new_row(button) {
    const $tbody = $(button).closest('table').find('tbody');
    const $newTr = $tbody.find('tr').last().clone();
    $newTr.find('input').val('');
    $tbody.append($newTr);
    this.setup_auto_complete_for_row($newTr);
    return $newTr;
  }

  setup_auto_complete_for_row($row) {
    const inputBox = $row.find('input.affiliation-entry-creator');
    const getDataFromROR = function getDataFromROR(request, response) {
      // ROR API: https://ror.readme.io/docs/rest-api
      // https://api.ror.org/organizations?query=
      // https://api.ror.org/organizations?query.advanced=name:Prin*
      $.getJSON(`${pdc.ror_url}?query.advanced=name:${request.term}*`, (data) => {
        const candidates = [];
        let i; let
          candidate;
        for (i = 0; i < data.items.length; i += 1) {
          candidate = { key: data.items[i].id, label: data.items[i].name };
          candidates.push(candidate);
        }
        response(candidates);
      });
    };

    $(inputBox).autocomplete({
      source: getDataFromROR,
      select(event, ui) {
        // Find the ROR input box for this row
        // and sets its ROR based on the selected organization
        const rorInput = $row.find('input.ror-input');
        $(rorInput).prop('value', ui.item.key);
      },
      minLength: 2,
      delay: 100,
    });
  }

  create_user_row(button) {
    let $newTr = this.find_empty_row(button);
    if ($newTr == null) {
      $newTr = this.create_new_row(button);
    }
    $newTr.find('.orcid-entry-creator').val(this.orcid);
    $newTr.find('.given-entry-creator').val(this.givenName);
    $newTr.find('.family-entry-creator').val(this.familyName);
  }

  find_empty_row(button) {
    const rows = $(button).closest('table').find('tbody').find('tr');
    let empty = null;
    for (const row of rows) {
      if ((new TableRow(row)).is_empty()) {
        empty = $(row);
        break;
      }
    }
    return empty;
  }

  delete_row(target) {
    const $target = $(target);
    const rowCount = $target.closest('tbody').find('tr').length;
    const $tr = $target.closest('tr');
    if (rowCount > 1) {
      $tr.remove();
    } else {
      // We use the row as a template, so we just blank it, if only one remains.
      $tr.find('input').val('');
    }
  }
}
