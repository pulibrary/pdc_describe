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

  function addCreatorHtml(num, orcid, givenName, familyName, sequence) {
    const rowId = `creator_row_${num}`;
    const orcidId = `orcid_${num}`;
    const givenNameId = `given_name_${num}`;
    const familyNameId = `family_name_${num}`;
    const sequenceId = `sequence_${num}`;
    const rowHtml = `<tr id="${rowId}" class="creators-table-row">
      <td>
        <input class="orcid-entry-creator" type="text" id="${orcidId}" name="${orcidId}" value="${orcid}" data-num="${num}" placeholder="0000-0000-0000-0000" />
      </td>
      <td>
        <input type="text" id="${givenNameId}" name="${givenNameId}" value="${givenName}" />
      </td>
      <td class="creators-table-row-family-name">
        <input type="text" id="${familyNameId}" name="${familyNameId}" value="${familyName}" />
      </td>
      <td>
        <input class="sequence hidden" type="text" id="${sequenceId}" name="${sequenceId}" value="${sequence}" />
      </td>
      <td>
        <i class="bi bi-arrow-down-up" style="color: gray;" title="Click and drag to reorder"></i>
      </td>
      <td>
        <span>
          <a class="delete-creator" data-creator-num="${num}" href="#" title="Remove this creator">
            <i class="bi bi-trash delete_icon" data-creator-num="${num}"></i>
          </a>
        </span>
      </td>
    </tr>`;
    $('#creators-table').append(rowHtml);
    $(`#${orcidId}`).focus();
  }

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

  function addContributorHtml(num, orcid, givenName, familyName, role, sequence) {
    const rowId = `contributor_row_${num}`;
    const orcidId = `contributor_orcid_${num}`;
    const roleId = `contributor_role_${num}`;
    const givenNameId = `contributor_given_name_${num}`;
    const familyNameId = `contributor_family_name_${num}`;
    const sequenceId = `contributor_sequence_${num}`;
    const roleHtml = makeSelectHtml(roleId, role, pdc.datacite.ContributorType, [
      /* Individual roles have been commented out, leaving just the roles of organizations. */

      // 'ContactPerson',
      // 'DataCollector',
      // 'DataCurator',
      // 'DataManager',
      'Distributor',
      // 'Editor',
      'Funder',
      'HostingInstitution',
      // 'Producer',
      // 'ProjectLeader',
      // 'ProjectManager',
      // 'ProjectMember',
      'RegistrationAgency',
      'RegistrationAuthority',
      // 'RelatedPerson',
      // 'Researcher',
      'ResearchGroup',
      // 'RightsHolder',
      // 'Sponsor',
      // 'Supervisor',
      // 'WorkPackageLeader',
      // 'Other',
    ]);

    const rowHtml = `<tr id="${rowId}" class="contributors-table-row">
      <td>
        <input class="orcid-entry-collaborator" type="text" id="${orcidId}" name="${orcidId}" value="${orcid}" data-num="${num}" placeholder="0000-0000-0000-0000" />
      </td>
      <td>
        <input type="text" id="${givenNameId}" name="${givenNameId}" value="${givenName}" />
      </td>
      <td class="contributors-table-row-family-name">
        <input type="text" id="${familyNameId}" name="${familyNameId}" value="${familyName}" />
      </td>
      <td>
        ${roleHtml}
      </td>
      <td>
        <input class="sequence hidden" type="text" id="${sequenceId}" name="${sequenceId}" value="${sequence}" />
      </td>
      <td>
        <i class="bi bi-arrow-down-up" style="color: gray;" title="Click and drag to reorder"></i>
      </td>
      <td>
        <span>
          <a class="delete-contributor" data-contributor-num="${num}" href="#" title="Remove this contributor">
            <i class="bi bi-trash delete_icon" data-contributor-num="${num}"></i>
          </a>
        </span>
      </td>
    </tr>`;
    $('#contributors-table').append(rowHtml);
    $(`#${orcidId}`).focus();
  }

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
      } else if (confirm(`Remove ${type} ${rowText}`)) {
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

  function peopleSorted(selector) {
    let i; let el; let
      creator;
    const creatorSpans = $(selector);
    const creators = [];
    for (i = 0; i < creatorSpans.length; i += 1) {
      el = $(creatorSpans[i]);
      creator = {
        num: el.data('num'),
        orcid: el.data('orcid'),
        givenName: el.data('given-name'),
        familyName: el.data('family-name'),
        sequence: el.data('sequence'),
        role: el.data('role'),
      };
      creators.push(creator);
    }
    creators.sort((a, b) => a.sequence - b.sequence);
    return creators;
  }

  // Returns true if the "user entered" textboxes for the row are empty.
  function isEmptyRow(rowId) {
    let selector; let textboxes; let i; let textboxId; let
      value;
    selector = `#${rowId} > td > input`;
    textboxes = $(selector);
    for (i = 0; i < textboxes.length; i += 1) {
      textboxId = textboxes[i].id;
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
  function findEmptyCreator() {
    let i;
    const rows = $('.creators-table-row');
    for (i = 0; i < rows.length; i += 1) {
      if (isEmptyRow(rows[i].id)) {
        return rows[i].id;
      }
    }
    return null;
  }

  // Returns true if there is at least one creator with information
  function hasCreators() {
    let i;
    const rows = $('.creators-table-row');
    for (i = 0; i < rows.length; i += 1) {
      if (!isEmptyRow(rows[i].id)) {
        return true;
      }
    }
    return false;
  }

  // Sets the values of a creator given a rowId
  function setCreatorValues(rowId, orcid, givenName, familyName) {
    const suffix = rowId.replace('creator_row_', '');
    $(`#orcid_${suffix}`).val(orcid);
    $(`#given_name_${suffix}`).val(givenName);
    $(`#family_name_${suffix}`).val(familyName);
  }

  // Fetch information via ORCID's public API and dumps the data into the elements indicated.
  function fetchOrcid(orcidValue, givenNameId, familyNameId) {
    if (isOrcid(orcidValue)) {
      $.ajax({
        url: `${pdc.orcid_url}/${orcidValue}`,
        dataType: 'jsonp',
      })
        .done((data) => {
          const givenName = data.person.name['given-names'].value;
          const familyName = data.person.name['family-name'].value;
          $(givenNameId).val(givenName);
          $(familyNameId).val(familyName);
        })
        .fail((XMLHttpRequest, textStatus, errorThrown) => {
          console.log(`Error fetching ORCID for ${errorThrown}`);
        });
    }
  }

  // This is generic and could be used to add blank rows to any table.
  $('.btn-add-row').on('click', (event) => {
    const $tbody = $(event.target).closest('table').find('tbody');
    const $newTr = $tbody.find('tr').last().clone();
    $newTr.find('input').val('');
    $tbody.append($newTr);
    return false;
  });

  $('#btn-add-creator').on('click', () => {
    const num = incrementCounter('#creator_count');
    addCreatorHtml(num, '', '', '');
    return false;
  });

  $('#btn-add-related-object').on('click', () => {
    const num = incrementCounter('#related_object_count');
    addRelatedObjectHtml(num, '', '', '');
    return false;
  });

  $('#btn-add-me-creator').on('click', () => {
    const num = incrementCounter('#creator_count');
    const orcid = $('#user_orcid').val();
    const givenName = $('#user_given_name').val();
    const familyName = $('#user_family_name').val();
    const emptyRowId = findEmptyCreator();
    if (emptyRowId == null) {
      addCreatorHtml(num, orcid, givenName, familyName);
    } else {
      setCreatorValues(emptyRowId, orcid, givenName, familyName);
    }
    return false;
  });

  $('#btn-add-contributor').on('click', () => {
    const num = incrementCounter('#contributor_count');
    addContributorHtml(num, '', '', '', 'Other');
    return false;
  });

  $('#btn-add-title').on('click', (event) => {
    addTitlePlaceholder(event);
    return false;
  });

  $('#btn-submit').on('click', () => {
    updateCreatorsSequence();
  });

  // Client side validations before allowing user to create the dataset.
  $('#btn-create-new').on('click', () => {
    const title = $('#title_main').val() || '';
    let status = true;

    $('#title-required-message').addClass('hidden');
    $('#creators-required-message').addClass('hidden');

    if (!hasCreators()) {
      $(`#${findEmptyCreator()}`).focus();
      $('#creators-required-message').removeClass('hidden');
      status = false;
    }

    if (title.trim() === '') {
      $('#title_main').focus();
      $('#title-required-message').removeClass('hidden');
      status = false;
    }

    return status;
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

  if ($('.creator-data').length === 0) {
    // Add an empty creator for the use to fill it out
    const num = incrementCounter('#creator_count');
    addCreatorHtml(num, '', '', '', 1);
  } else {
    // Adds the existing creators making sure we honor the ordering.
    const creators = peopleSorted('.creator-data');
    for (let i = 0; i < creators.length; i += 1) {
      const creator = creators[i];
      addCreatorHtml(
        creator.num,
        creator.orcid,
        creator.givenName,
        creator.familyName,
        creator.sequence,
      );
    }
  }

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

  if ($('.contributor-data').length === 0) {
    // Add an empty contributor for the use to fill it out
    const num = incrementCounter('#contributor_count');
    addContributorHtml(num, '', '', '', 'Other', 1);
  } else {
    // Adds the existing contributors making sure we honor the ordering.
    const contributors = peopleSorted('.contributor-data');
    for (i = 0; i < contributors.length; i += 1) {
      const contributor = contributors[i];
      addContributorHtml(
        contributor.num,
        contributor.orcid,
        contributor.givenName,
        contributor.familyName,
        contributor.role,
        contributor.sequence,
      );
    }
  }

  // Fetch information for a creator via ORCID's public API
  $(document).on('input', '.orcid-entry-creator', (el) => {
    const num = el.target.attributes['data-num'].value;
    const orcid = $(el.target).val().trim();
    fetchOrcid(orcid, `#given_name_${num}`, `#family_name_${num}`);
  });

  // Fetch information for a collaborator/contributor via ORCID's public API
  $(document).on('input', '.orcid-entry-collaborator', (el) => {
    const num = el.target.attributes['data-num'].value;
    const orcid = $(el.target).val().trim();
    fetchOrcid(orcid, `#contributor_given_name_${num}`, `#contributor_family_name_${num}`);
  });

  // Drop the "http..."" portion of the URL if the user enters the full URL of a DataSpace ARK
  // http://arks.princeton.edu/ark:/88435/dsp01hx11xj13h => ark:/88435/dsp01hx11xj13h
  $('#ark').on('input', (el) => {
    const prefix = 'http://arks.princeton.edu/';
    const ark = el.currentTarget.value.trim();
    if (ark.startsWith(prefix)) {
      el.currentTarget.value = ark.replace(prefix, '');
    }
  });

  // Fetch information for funder via the ROR API
  $(document).on('change', '.ror-input', (el) => {
    const $target = $(el.target);
    const ror = $target.val().trim();
    fetch(`https://api.ror.org/organizations/${ror}`).then()
      .then((response) => response.json())
      .then((responseJson) => {
        const { name } = responseJson;
        $target.closest('tr').find('.ror-output').val(name);
      });
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
    cancel: 'input, select, option, .delete-contributor, .delete-creator',
  });

  // Give the initial focus to the title.
  $('#title_main').focus();
});
