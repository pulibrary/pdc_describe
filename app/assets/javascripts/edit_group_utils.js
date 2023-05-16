$(() => {
  // Issues the HTTP DELETE to remove a user's access from a group
  function deleteUserFromGroup(el, url, uid) {
    $.ajax({
      type: 'DELETE',
      url: url.replace('uid-placeholder', uid),
      data: { authenticity_token: pdc.formAuthenticityToken },
      success() {
        // Remove the <li> for the user
        $(`.li-user-${uid}`).remove();
      },
      error(x) {
        alert(x.responseJSON.message);
      },
    });
  }

  // Adds the information for a given user to the lists of administrators/submitters
  // for the group.
  // `elList` is the reference to the <ul> HTML element that hosts the list.
  function addUserHtml(elList, uid, groupId, role, canDelete, isYou, isSuperAdmin) {
    const baseUserUrl = pdc.userPath;
    const showUserUrl = baseUserUrl.replace('user-placeholder', uid);
    let html = `<li class="li-user-${uid}"> <a href="${showUserUrl}">${uid}</a>`;
    if (isYou) {
      html += ' (you)';
    }
    if (isSuperAdmin) {
      html += ' <i title="This is a system administrator, access cannot be changed." class="bi bi-person-workspace"></i>';
    }
    if (canDelete) {
      html += `
        <span>
        <a class="delete-user-from-group" data-group-id="${groupId}" data-uid="${uid}"
          href="#" title="Revoke user's ${role} access this group">
          <i class="bi bi-trash delete_icon" data-group-id="${groupId}" data-uid="${uid}"></i>
        </a>
      </span>`;
    }
    $(elList).append(html);
  }

  // Issues the HTTP POST to add a user to a group and updates the UI
  function addUserToGroup(url, elTxt, elError, elList, role) {
    const { groupId } = pdc;
    const uid = $(elTxt).val().trim();
    if (uid === '') {
      $(elError).text('Enter netid of user to add');
      return;
    }

    $.ajax({
      type: 'POST',
      url: url.replace('uid-placeholder', uid),
      data: { authenticity_token: pdc.formAuthenticityToken },
      success() {
        $(elTxt).val('');
        $(elError).text('');
        const canDelete = true;
        const isYou = false;
        const isSuperAdmin = false;
        addUserHtml(elList, uid, groupId, role, canDelete, isYou, isSuperAdmin);
      },
      error(x) {
        $(elError).text(x.responseJSON.message);
      },
    });
  }

  // Adds a submitter to the group
  $('#btn-add-submitter').on('click', () => {
    const url = pdc.addSubmitterUrl;
    addUserToGroup(url, '#submitter-uid-to-add', '#add-submitter-message', '#submitter-list', 'submit');
    $('#submitter-uid-to-add').focus();
    return false;
  });

  // Adds an administrator to the group
  $('#btn-add-admin').on('click', () => {
    const url = pdc.addAdminUrl;
    addUserToGroup(url, '#admin-uid-to-add', '#add-admin-message', '#curator-list', 'admin');
    $('#admin-uid-to-add').focus();
    return false;
  });

  if ($('#data-loaded').text() !== 'true') {
    // Displays the initial list of submitters.
    $('.submitter-data').each((ix, el) => {
      const elList = $('#submitter-list');
      const uid = $(el).data('uid');
      const groupId = $(el).data('groupId');
      const canDelete = $(el).data('canDelete');
      const isYou = $(el).data('you');
      const isSuperAdmin = false;
      addUserHtml(elList, uid, groupId, 'submit', canDelete, isYou, isSuperAdmin);
    });

    // Displays the initial list of curators.
    $('.curator-data').each((ix, el) => {
      const elList = $('#curator-list');
      const uid = $(el).data('uid');
      const groupId = $(el).data('groupId');
      const canDelete = $(el).data('canDelete');
      const isYou = $(el).data('you');
      addUserHtml(elList, uid, groupId, 'admin', canDelete, isYou, false);
    });

    // Displays the list of system administrators.
    $('.sysadmin-data').each((ix, el) => {
      const elList = $('#sysadmin-list');
      const uid = $(el).data('uid');
      const groupId = $(el).data('groupId');
      const isYou = $(el).data('you');
      addUserHtml(elList, uid, groupId, 'admin', false, isYou, true);
    });

    // Track that we have displayed this information. This prevents re-display when
    // user click the Back/Forward button on their browser.
    $('<span id="data-loaded" class="hidden">true</span>').appendTo('body');
  }

  // Wire up the delete button for all users listed in the group.
  //
  // Notice the use of $(document).on("click", selector, ...) instead of the
  // typical $(selector).on("click", ...). This syntax is required so that
  // we can detect the click even on HTML elements _added on the fly_ which
  // is the case when a user adds a new submitter or admin to the group.
  // Reference: https://stackoverflow.com/a/17086311/446681
  $(document).on('click', '.delete-user-from-group', (el) => {
    const url = pdc.deleteUserFromGroupUrl;
    const uid = $(el.target).data('uid');
    const message = `Revoke access to user ${uid}`;
    if (window.confirm(message)) {
      deleteUserFromGroup(el, url, uid);
    }
    return false;
  });
});
