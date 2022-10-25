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

Vite wraps it as an ESM, and there doesn't seem to be a way to specify an export that we can call as-needed.
*/

console.log('edit_utils.js loaded...')
$(function () {
  console.log('edit_utils.js hooks loading...')
  var incrementCounter = function(elementId) {
    var counter = parseInt($(elementId)[0].value, 10);
    counter++
    $(elementId)[0].value = counter
    return counter
  }

  var addCreatorHtml = function(num, orcid, givenName, familyName, sequence) {
    var rowId = `creator_row_${num}`;
    var orcidId = `orcid_${num}`;
    var givenNameId = `given_name_${num}`;
    var familyNameId = `family_name_${num}`;
    var sequenceId = `sequence_${num}`;
    var rowHtml = `<tr id="${rowId}" class="creators-table-row">
      <td>
        <input class="orcid-entry" type="text" id="${orcidId}" name="${orcidId}" value="${orcid}" data-num="${num}" placeholder="0000-0000-0000-0000" />
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
    $("#creators-table").append(rowHtml);
    $("#" + orcidId).focus();
  }

  function makeSelectHtml(selectId, currentKey, kvList) {
    const options = kvList.map(
      ({key, value}) => 
      `<option value="${key}" ${currentKey == key ? "selected" : ""}>${value}</option>`
    );
    return `<select id="${selectId}" name="${selectId}">${options}</select>`
  }

  // ************************************************ //
  // Related Objects
  // related_identifier:, related_identifier_type:, relation_type
  var addRelatedObjectHtml = function(num, related_identifier, related_identifier_type, relation_type) {
    var rowId = `related_object_row_${num}`;
    var relatedIdentifierId = `related_identifier_${num}`;
    var relatedIdentifierTypeId = `related_identifier_type_${num}`;
    var relationTypeId = `relation_type_${num}`;
    var relatedIdentifierTypeHtml = makeSelectHtml(relatedIdentifierTypeId, related_identifier_type, pdc.datacite.RelatedIdentifierType);
    var relationTypeHtml = makeSelectHtml(relationTypeId, relation_type, pdc.datacite.RelationType);

    var rowHtml = `<tr id="${rowId}" class="related-objects-table-row">
      <td>
        <input type="text" id="${relatedIdentifierId}" name="${relatedIdentifierId}" value="${related_identifier}" data-num="${num}" placeholder="The URL web address for a related publication or other resource" />
      </td>
      <td>
        ${relatedIdentifierTypeHtml}
      </td>
      <td>
        ${relationTypeHtml}
      </td>
    </tr>`;
    $("#related-objects-table").append(rowHtml);
  }

  // ************************************************ //

  var addContributorHtml = function(num, orcid, givenName, familyName, role, sequence) {
    var rowId = `contributor_row_${num}`;
    var orcidId = `contributor_orcid_${num}`;
    var roleId = `contributor_role_${num}`;
    var givenNameId = `contributor_given_name_${num}`;
    var familyNameId = `contributor_family_name_${num}`;
    var sequenceId = `contributor_sequence_${num}`;
    var roleHtml = makeSelectHtml(roleId, role, pdc.datacite.ContributorType);

    var rowHtml = `<tr id="${rowId}" class="contributors-table-row">
      <td>
        <input class="orcid-entry" type="text" id="${orcidId}" name="${orcidId}" value="${orcid}" data-num="${num}" placeholder="0000-0000-0000-0000" />
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
    $("#contributors-table").append(rowHtml);
    $("#" + orcidId).focus();
  }

  var deletePerson = function(rowToDelete, type) {
    var rowExists = $(rowToDelete).length > 0;
    var rowData = $(rowToDelete + " input:not(.hidden)");
    var i, token;
    var rowText = "";
    for(i = 0; i < rowData.length; i++) {
      token = $(rowData[i]).val();
      if (token.trim().length > 0) {
        rowText += token + " ";
      }
    }
    var emptyRow = (rowText.trim().length == 0);
    if (rowExists) {
      if (emptyRow) {
        // delete it without asking
        $(rowToDelete).remove();
      } else {
        if (confirm(`Remove ${type} ${rowText}`)) {
          $(rowToDelete).remove();
        }
      }
    }
  }

  var deleteCreator = function(num) {
    deletePerson(`#creator_row_${num}`, "creator")
  }

  var deleteContributor = function(num) {
    deletePerson(`#contributor_row_${num}`, "contributor")
  }

  // Updates the creators sequence value to match the order
  // in which they are displayed. This is needed if the user
  // reordered the creators (via drag and drop).
  var updateCreatorsSequence = function() {
    var i;
    var sequences = $(".creators-table-row > td > input.sequence")
    for(i = 0; i < sequences.length; i++) {
      sequences[i].value = i + 1;
    }
  }

  var addTitlePlaceholder = function(_el) {
    var newTitleCount = incrementCounter("#new_title_count");
    var containerId = `new_title_container_${newTitleCount}`;
    var titleId = `new_title_${newTitleCount}`;
    var typeId = `new_title_type_${newTitleCount}`;
    var html = `
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
    $("#new-titles-anchor").append(html);
  }

  var peopleSorted = function(selector) {
    var i, el, creator;
    var creatorSpans = $(selector);
    var creators = [];
    for(i = 0; i < creatorSpans.length; i++) {
      el = $(creatorSpans[i]);
      creator = {
        num: el.data("num"),
        orcid: el.data("orcid"),
        givenName: el.data("given-name"),
        familyName: el.data("family-name"),
        sequence: el.data("sequence"),
        role: el.data("role")
      }
      creators.push(creator);
    }
    creators.sort(function(a, b) { return a.sequence - b.sequence});
    return creators;
  }

  // Returns true if the "user entered" textboxes for the row are empty.
  var isEmptyRow = function(rowId) {
    var selector, textboxes, i, textboxId, value;
    selector = `#${rowId} > td > input`;
    textboxes = $(selector);
    for(i = 0; i < textboxes.length; i++) {
      textboxId = textboxes[i].id;
      if (textboxId.startsWith("orcid_") || textboxId.startsWith("given_name_") || textboxId.startsWith("family_name_")) {
        value = $("#" + textboxId).val().trim();
        if (value!= "") {
          return false;
        };
      }
    }
    return true;
  }

  // Returns the ID of the first row that has an empty creator (if any)
  var findEmptyCreator = function() {
    var i;
    var rows = $(".creators-table-row");
    for(i = 0; i < rows.length; i++) {
      if (isEmptyRow(rows[i].id)) {
        return rows[i].id;
      }
    };
    return null;
  }

  // Returns true if there is at least one creator with information
  var hasCreators = function() {
    var i;
    var rows = $(".creators-table-row");
    for(i = 0; i < rows.length; i++) {
      if (!isEmptyRow(rows[i].id)) {
        return true;
      }
    };
    return false;
  }

  // Sets the values of a creator given a rowId
  var setCreatorValues = function(rowId, orcid, givenName, familyName) {
    var suffix = rowId.replace("creator_row_", "");
    $("#orcid_" + suffix).val(orcid);
    $("#given_name_" + suffix).val(givenName);
    $("#family_name_" + suffix).val(familyName);
  }

  $("#btn-add-creator").on("click", function(el) {
    var num = incrementCounter("#creator_count");
    addCreatorHtml(num, "", "", "");
    return false;
  });

  $("#btn-add-related-object").on("click", function(el) {
    var num = incrementCounter("#related_object_count");
    addRelatedObjectHtml(num, "", "", "");
    return false;
  });

  $("#btn-add-me-creator").on("click", function(el) {
    var num = incrementCounter("#creator_count");
    var orcid = $("#user_orcid").val()
    var givenName = $("#user_given_name").val()
    var familyName = $("#user_family_name").val()
    var emptyRowId = findEmptyCreator();
    if (emptyRowId == null) {
      addCreatorHtml(num, orcid, givenName, familyName);
    } else {
      setCreatorValues(emptyRowId, orcid, givenName, familyName)
    }
    return false;
  });

  $("#btn-add-contributor").on("click", function(el) {
    var num = incrementCounter("#contributor_count");
    addContributorHtml(num, "", "", "", "Other");
    return false;
  });

  $("#btn-add-title").on("click", function(el) {
    addTitlePlaceholder(el);
    return false;
  });

  $("#btn-submit").on("click", function(el) {
    updateCreatorsSequence();
  });

  // Client side validations before allowing user to create the dataset.
  $("#btn-create-new").on("click", function(el) {
    var title = $("#title_main").val() || "";
    var status = true;

    $("#title-required-message").addClass("hidden");
    $("#creators-required-message").addClass("hidden");

    if (!hasCreators()) {
      $("#" + findEmptyCreator()).focus();
      $("#creators-required-message").removeClass("hidden");
      status = false;
    }

    if (title.trim() == "") {
      $("#title_main").focus();
      $("#title-required-message").removeClass("hidden");
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
  $(document).on("click", ".delete-creator", function(el) {
    var num = $(el.target).data("creator-num");
    deleteCreator(num);
    return false;
  });

  $(document).on("click", ".delete-contributor", function(el) {
    var num = $(el.target).data("contributor-num");
    deleteContributor(num);
    return false;
  });

  $(document).on("click", ".delete-title", function(el) {
    var num = $(el.target).data("title-num");
    var selector = `#new_title_container_${num}`
    $(selector).remove();
    return false;
  });

  if ($(".creator-data").length ==0) {
    // Add an empty creator for the use to fill it out
    var num = incrementCounter("#creator_count");
    addCreatorHtml(num, "", "", "", 1);
  } else {
    // Adds the existing creators making sure we honor the ordering.
    var creators = peopleSorted(".creator-data");
    for(let i = 0; i < creators.length; i++) {
      var creator = creators[i];
      addCreatorHtml(creator.num, creator.orcid, creator.givenName, creator.familyName, creator.sequence);
    }
  }

  // Load any existing related objects into the edit form.
  // If there are any related objects they should appear in hidden <span> tags.
  if ($(".related-object-data").length == 0) {
    // Add an empty related object for the user to fill it out
    var num = incrementCounter("#related_object_count");
    addRelatedObjectHtml(num, "", "", "");
  } else {
    // Add existing related objects for editing
    for (const related_object of $(".related-object-data")) {
      const {num, relatedIdentifier, relatedIdentifierType, relationType} = related_object.dataset
      addRelatedObjectHtml(num, relatedIdentifier, relatedIdentifierType, relationType);
    }
  }

  if ($(".contributor-data").length == 0) {
    // Add an empty contributor for the use to fill it out
    var num = incrementCounter("#contributor_count");
    addContributorHtml(num, "", "", "", "Other", 1);
  } else {
    // Adds the existing contributors making sure we honor the ordering.
    var contributors = peopleSorted(".contributor-data");
    for(i = 0; i < contributors.length; i++) {
      var contributor = contributors[i];
      addContributorHtml(contributor.num, contributor.orcid, contributor.givenName, contributor.familyName, contributor.role, contributor.sequence);
    }
  }

  // Fetch name information for a given ORCID via ORCID's public API
  $(document).on("input", ".orcid-entry", function(el) {
    var num = el.target.attributes["data-num"].value;
    var orcid = $(el.target).val().trim();
    if (isOrcid(orcid)) {
      $.ajax({
        url: `${pdc.orcid_url}/${orcid}`,
        dataType: 'jsonp'
      })
      .done(function(data) {
        var givenName = data.person.name["given-names"].value;
        var familyName = data.person.name["family-name"].value;
        var givenNameId = `#given_name_${num}`;
        var familyNameId = `#family_name_${num}`;
        $(givenNameId).val(givenName);
        $(familyNameId).val(familyName);
      })
      .fail(function(XMLHttpRequest, textStatus, errorThrown) {
        console.log(`Error fetching ORCID for ${errorThrown}`);
      });
    }
  });

  // Drop the "http..."" portion of the URL if the user enters the full URL of a DataSpace ARK
  // http://arks.princeton.edu/ark:/88435/dsp01hx11xj13h => ark:/88435/dsp01hx11xj13h
  $("#ark").on("input", function(el) {
    var prefix = "http://arks.princeton.edu/";
    var ark = el.currentTarget.value.trim();
    if (ark.startsWith(prefix)) {
      el.currentTarget.value = ark.replace(prefix, "")
    }
  });

  // Allows the creators and contributors to be reordered via drag and drop.
  // The `cancel` property "prevents sorting if you start on elements matching the selector"
  // https://api.jqueryui.com/sortable/#method-cancel
  //
  //  tr:has(th)      - prevents reordering the header (https://stackoverflow.com/a/17897706/446681)
  //  input           - prevents reordering on the textboxes (so they are still editable)
  //  select, option  - prevents reordering on the dropwdown (so they are still selectable)
  //  .delete-creator - prevents reording on the delete icon
  //
  $("#creators-table-sortable").sortable({
    cancel: "tr:has(th), input, .delete-creator"
  });

  $("#contributors-table-sortable").sortable({
    cancel: "tr:has(th), input, select, option, .delete-contributor"
  });

  // Give the initial focus to the title.
  $("#title_main").focus();
});
