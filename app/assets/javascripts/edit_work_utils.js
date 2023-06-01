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

  // ************************************************ //

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

  $('#btn-add-title').on('click', (event) => {
    addTitlePlaceholder(event);
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

  // Allows the multi-fields to be reordered via drag and drop.
  // The `cancel` property "prevents sorting if you start on elements matching the selector"
  // https://api.jqueryui.com/sortable/#method-cancel
  //
  //  input           - prevents reordering on the textboxes (so they are still editable)
  //  select, option  - prevents reordering on the dropwdown (so they are still selectable)
  //  .btn-del-row    - prevents reordering on the delete icon
  //
  $('.sortable').sortable({
    cancel: 'input, select, option, .btn-del-row',
  });

  // Give the initial focus to the title.
  $('#title_main').focus();
});
