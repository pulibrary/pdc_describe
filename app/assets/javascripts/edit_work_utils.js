/*
This is an interim solution: My sense is that jQuery doesn't work well with Vite and Turbolinks.

The standard approach would be
- vite_javascript_tag,
- active on every page of the application,
- and hooks that don't assume the element is already on the page.

We considered running this for every page of the application, but it causes test failures:
some of the jQuery hooks interfere with the operation of other pages.

Turbolinks means that we don't get the expected page-load event,
so the hooks aren't registered on successive visits to the page.

Vite wraps it as an ESM, and there doesn't seem to be a way to specify
an export that we can call as-needed.
*/

$(() => {
  function incrementCounter(elementId) {
    let counter = parseInt($(elementId)[0].value, 10);
    counter += 1;
    $(elementId)[0].value = counter;
    return counter;
  }

  // Creates an HTML select from a string array (keys and display values are identical)
  function makeSelectHtml(selectId, currentValue, allValues, blocklist = []) {
    const options = allValues.filter(
      (value) => !blocklist.includes(value),
    ).map(
      (value) => `<option value="${value}" ${currentValue === value ? 'selected' : ''}>${value}</option>`,
    );
    return `<select id="${selectId}" name="${selectId}"><option value="" ${currentValue === '' ? 'selected' : ''}></option>${options}</select>`;
  }

  // ************************************************ //
  // Related Objects
  // related_identifier:, related_identifier_type:, relation_type
  function addRelatedObjectHtml(num, relatedIdentifier, relatedIdentifierType, relationType) {
    const rowId = `related_object_row_${num}`;
    const relatedIdentifierId = `related_identifier_${num}`;
    const relatedIdentifierTypeId = `related_identifier_type_${num}`;
    const relationTypeId = `relation_type_${num}`;
    const relatedIdentifierTypeHtml = makeSelectHtml(
      relatedIdentifierTypeId,
      relatedIdentifierType,
      pdc.datacite.RelatedIdentifierType,
    );
    const relationTypeHtml = makeSelectHtml(
      relationTypeId,
      relationType,
      pdc.datacite.RelationType,
    );

    const rowHtml = `<tr id="${rowId}" class="related-objects-table-row">
      <td>
        <input type="text" id="${relatedIdentifierId}" name="${relatedIdentifierId}" value="${relatedIdentifier}" data-num="${num}"/>
      </td>
      <td>
        ${relatedIdentifierTypeHtml}
      </td>
      <td>
        ${relationTypeHtml}
      </td>
    </tr>`;
    $('#related-objects-table').append(rowHtml);
  }

  // ************************************************ //

  function deletePerson(rowToDelete, type) {
    const rowExists = $(rowToDelete).length > 0;
    const rowData = $(`${rowToDelete} input:not(.hidden)`);
    let i; let
      token;
    let rowText = '';
    for (i = 0; i < rowData.length; i += 1) {
      token = $(rowData[i]).val();
      if (token.trim().length > 0) {
        rowText += `${token} `;
      }
    }
    const emptyRow = (rowText.trim().length === 0);
    if (rowExists) {
      if (emptyRow) {
        // delete it without asking
        $(rowToDelete).remove();
      } else if (window.confirm(`Remove ${type} ${rowText}`)) {
        $(rowToDelete).remove();
      }
    }
  }

  function deleteCreator(num) {
    deletePerson(`#creator_row_${num}`, 'creator');
  }

  function deleteContributor(num) {
    deletePerson(`#contributor_row_${num}`, 'contributor');
  }

  // Updates the creators sequence value to match the order
  // in which they are displayed. This is needed if the user
  // reordered the creators (via drag and drop).
  function updateCreatorsSequence() {
    let i;
    const sequences = $('.creators-table-row > td > input.sequence');
    for (i = 0; i < sequences.length; i += 1) {
      sequences[i].value = i + 1;
    }
  }

  function addTitlePlaceholder() {
    const newTitleCount = incrementCounter('#new_title_count');
    const containerId = `new_title_container_${newTitleCount}`;
    const titleId = `new_title_${newTitleCount}`;
    const typeId = `new_title_type_${newTitleCount}`;
    const html = `
      <div id="${containerId}" class="field">
        <select id="${typeId}" name="${typeId}">
          <option value="AlternativeTitle">Alternative Title</option>
          <option value="Subtitle">Subtitle</option>
          <option value="TranslatedTitle">Translated Title</option>
          <option value="Other">Other Title</option>
        </select>
        <br>
        <input type="text" id="${titleId}" name="${titleId}" value="" class="input-text-long" />
        <span>
          <a class="delete-title" data-title-num="${newTitleCount}" href="#" title="Remove this title">
            <i class="bi bi-trash delete_icon" data-title-num="${newTitleCount}"></i>
          </a>
        </span>
      </div>`;
    $('#new-titles-anchor').append(html);
  }

  // This is generic and can be used to remove rows from any table.
  $(document).on('click', '.btn-del-row', (event) => {
    const $target = $(event.target);
    const rowCount = $target.closest('tbody').find('tr').length;
    const $tr = $target.closest('tr');
    if (rowCount > 1) {
      $tr.remove();
    } else {
      // We use the row as a template, so we just blank it, if only one remains.
      $tr.find('input').val('');
    }
    return false;
  });

  $('#btn-add-related-object').on('click', () => {
    const num = incrementCounter('#related_object_count');
    addRelatedObjectHtml(num, '', '', '');
    return false;
  });

  $('#btn-add-title').on('click', (event) => {
    addTitlePlaceholder(event);
    return false;
  });

  $('#btn-submit').on('click', () => {
    updateCreatorsSequence();
  });

  // Delete button for creators.
  //
  // Notice the use of $(document).on("click", selector, ...) instead of the
  // typical $(selector).on("click", ...). This syntax is required so that
  // we can detect the click even on HTML elements _added on the fly_ which
  // is the case when a user adds a new creator.
  // Reference: https://stackoverflow.com/a/17086311/446681
  $(document).on('click', '.delete-creator', (el) => {
    const num = $(el.target).data('creator-num');
    deleteCreator(num);
    return false;
  });

  $(document).on('click', '.delete-contributor', (el) => {
    const num = $(el.target).data('contributor-num');
    deleteContributor(num);
    return false;
  });

  $(document).on('click', '.delete-title', (el) => {
    const num = $(el.target).data('title-num');
    const selector = `#new_title_container_${num}`;
    $(selector).remove();
    return false;
  });

  // Handles delete of files
  $(document).on('click', '.delete-file', (el) => {
    // Mark the file as deleted in the UI.
    // Relevant DataTables documentation for individual row manipulation:
    //   https://datatables.net/reference/api/data()
    //   https://datatables.net/reference/type/row-selector
    const safeId = $(el.target).data('safe_id');
    const rowId = `#${safeId}`;
    const filesTable = $('#files-table').DataTable();
    const row = filesTable.row(rowId).data();
    row.filename_display = `* #${row.filename_display}`;
    filesTable.row(rowId).invalidate();

    // Keep track of the deleted file, we do this via a hidden textbox with
    // the name of the file to delete. This information will be submitted
    // to the server when the user hits save.
    const deleteCount = incrementCounter('#deleted_files_count');
    const sequenceId = `deleted_file_${deleteCount}`;
    const deletedFileHtml = `<input class="hidden deleted-file-tracker" type="text" id="${sequenceId}" name="work[${sequenceId}]" value="${row.filename}" />`;
    $('.work-form').append(deletedFileHtml);
    return false;
  });

  // Handles undo delete of files
  $(document).on('click', '.undo-delete-file', (el) => {
    const safeId = $(el.target).data('safe_id');
    const rowId = `#${safeId}`;
    // Mark the file as not deleted in the UI.
    const filesTable = $('#files-table').DataTable();
    const row = filesTable.row(rowId).data();
    row.filename_display = row.filename_display.replace('* ', '');
    filesTable.row(rowId).invalidate();

    // Remove the filename from the list of values we submit to the server.
    $('.deleted-file-tracker').each((_index, element) => {
      if (element.value === row.filename) {
        element.value = ''; // eslint-disable-line no-param-reassign
      }
    });
    return false;
  });

  // Load any existing related objects into the edit form.
  // If there are any related objects they should appear in hidden <span> tags.
  if ($('.related-object-data').length === 0) {
    // Add an empty related object for the user to fill it out
    const num = incrementCounter('#related_object_count');
    addRelatedObjectHtml(num, '', '', '');
  } else {
    // Add existing related objects for editing
    for (const relatedObject of $('.related-object-data')) {
      const {
        num, relatedIdentifier, relatedIdentifierType, relationType,
      } = relatedObject.dataset;
      addRelatedObjectHtml(num, relatedIdentifier, relatedIdentifierType, relationType);
    }
  }

  // Drop the "http..."" portion of the URL if the user enters the full URL of a DataSpace ARK
  // http://arks.princeton.edu/ark:/88435/dsp01hx11xj13h => ark:/88435/dsp01hx11xj13h
  $('#ark').on('input', (event) => {
    const prefix = 'http://arks.princeton.edu/';
    const target = event.currentTarget;
    const ark = target.value.trim();
    if (ark.startsWith(prefix)) {
      target.value = ark.replace(prefix, '');
    }
  });

  // Allows the creators and contributors to be reordered via drag and drop.
  // The `cancel` property "prevents sorting if you start on elements matching the selector"
  // https://api.jqueryui.com/sortable/#method-cancel
  //
  //  input           - prevents reordering on the textboxes (so they are still editable)
  //  select, option  - prevents reordering on the dropwdown (so they are still selectable)
  //  .delete-creator - prevents reording on the delete icon
  //
  $('.sortable').sortable({
    cancel: 'input, select, option, .delete-contributor, .delete-creator, .btn-del-row',
  });

  // Give the initial focus to the title.
  $('#title_main').focus();
});
