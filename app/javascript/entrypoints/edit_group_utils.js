class EditGroupUtils {
  constructor(jQuery) {
    this.$ = jQuery;

    this.pdc = null;
  }

  bind(pdc) {
    this.pdc = pdc;

    // Adds a submitter to the group
    $('#btn-add-submitter').on('click', this.onAddSubmitter.bind(this));

    // Adds an administrator to the group
    $('#btn-add-admin').on('click', this.onAddAdmin.bind(this));

    const $dataLoaded = this.$('#data-loaded');
    const dataLoaded = $dataLoaded.text();

    if (dataLoaded !== 'true') {
      // Displays the initial list of submitters.
      const $submitters = this.$('.submitter-data');
      $submitters.each((ix, el) => {
        const elList = this.$('#submitter-list');
        const $el = this.$(el);
        const uid = $el.data('uid');
        const groupId = $el.data('groupId');
        const canDelete = $el.data('canDelete');
        const isYou = $el.data('you');
        const isSuperAdmin = false;
        this.addUserHtml(elList, uid, groupId, 'submit', canDelete, isYou, isSuperAdmin);
      });

      // Displays the initial list of curators.
      const $curators = this.$('.curator-data');
      $curators.each((ix, el) => {
        const elList = $('#curator-list');
        const $el = this.$(el);
        const uid = $el.data('uid');
        const groupId = $el.data('groupId');
        const canDelete = $el.data('canDelete');
        const isYou = $el.data('you');
        this.addUserHtml(elList, uid, groupId, 'admin', canDelete, isYou, false);
      });

      // Displays the list of system administrators.
      const $sysadmins = this.$('.sysadmin-data');
      $sysadmins.each((ix, el) => {
        const elList = $('#sysadmin-list');
        const $el = this.$(el);
        const uid = $el.data('uid');
        const groupId = $el.data('groupId');
        const isYou = $el.data('you');
        this.addUserHtml(elList, uid, groupId, 'admin', false, isYou, true);
      });

      // Track that we have displayed this information. This prevents re-display when
      // user click the Back/Forward button on their browser.
      const $newDataLoaded = $('<span id="data-loaded" class="hidden">true</span>');
      $newDataLoaded.appendTo('body');
    }

    // Wire up the delete button for all users listed in the group.
    //
    // Notice the use of $(document).on("click", selector, ...) instead of the
    // typical $(selector).on("click", ...). This syntax is required so that
    // we can detect the click even on HTML elements _added on the fly_ which
    // is the case when a user adds a new submitter or admin to the group.
    // Reference: https://stackoverflow.com/a/17086311/446681
    $(document).on('click', '.delete-user-from-group', (event) => {
      const url = this.pdc.deleteUserFromGroupUrl;
      const $target = this.$(event.target);
      const uid = $target.data('uid');
      const message = `Revoke access to user ${uid}`;
      const confirmed = window.confirm(message);
      if (confirmed) {
        this.deleteUserFromGroup(event, url, uid);
      }
      return false;
    });
  }

  onAddSubmitter() {
    const url = this.pdc.addSubmitterUrl;
    this.addUserToGroup(
      url,
      '#submitter-uid-to-add',
      '#add-submitter-message',
      '#submitter-list',
      'submit',
    );
    $('#submitter-uid-to-add').focus();
    return false;
  }

  onAddAdmin() {
    const url = this.pdc.addAdminUrl;
    this.addUserToGroup(
      url,
      '#admin-uid-to-add',
      '#add-admin-message',
      '#curator-list',
      'admin',
    );
    $('#admin-uid-to-add').focus();
    return false;
  }

  // Issues the HTTP DELETE to remove a user's access from a group
  deleteUserFromGroup(event, url, uid) {
    const { currentTarget } = event;
    const $currentTarget = this.$(currentTarget);
    this.$listItem = $currentTarget.parents(`.li-user-${uid}`);

    const onSuccess = () => {
      // Remove the <li> for the user
      this.$listItem.remove();
    };

    const onError = (error) => {
      const { responseJSON } = error;
      this.$elError.text(responseJSON.message);
    };

    this.$.ajax({
      type: 'DELETE',
      url: url.replace('uid-placeholder', uid),
      data: { authenticity_token: this.pdc.formAuthenticityToken },
      success: onSuccess.bind(this),
      error: onError.bind(this),
    });
  }

  // Adds the information for a given user to the lists of administrators/submitters
  // for the group.
  // `elList` is the reference to the <ul> HTML element that hosts the list.
  addUserHtml(elList, uid, groupId, role, canDelete, isYou, isSuperAdmin) {
    const { userPath } = this.pdc;
    const showUserUrl = userPath.replace('user-placeholder', uid);
    let html = `<li class="li-user-${uid}"> <a href="${showUserUrl}">${uid}</a>`;
    if (isYou) {
      html += ' (you)';
    }
    if (isSuperAdmin) {
      html +=
        ' <i title="This is a system administrator, access cannot be changed." class="bi bi-person-workspace"></i>';
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
    const $elList = this.$(elList);
    $elList.append(html);
  }

  // Issues the HTTP POST to add a user to a group and updates the UI
  addUserToGroup(url, elTxt, elError, elList, role) {
    const { groupId } = this.pdc;
    this.groupId = groupId;

    this.elList = elList;
    this.role = role;

    this.$elTxt = this.$(elTxt);
    const elValue = this.$elTxt.val();
    this.uid = elValue.trim();

    this.$elError = this.$(elError);

    if (this.uid === '') {
      this.$elError.text('Please enter NetID of the user to add.');
      return;
    }

    const onSuccess = () => {
      this.$elTxt.val('');
      this.$elError.text('');
      const canDelete = true;
      const isYou = false;
      const isSuperAdmin = false;
      // eslint-disable-next-line max-len
      this.addUserHtml(
        this.elList,
        this.uid,
        this.groupId,
        this.role,
        canDelete,
        isYou,
        isSuperAdmin,
      );
      // eslint-enable-next-line max-len
    };

    const onError = (error) => {
      const { responseJSON } = error;
      this.$elError.text(responseJSON.message);
    };

    $.ajax({
      type: 'POST',
      url: url.replace('uid-placeholder', this.uid),
      data: { authenticity_token: this.pdc.formAuthenticityToken },
      success: onSuccess.bind(this),
      error: onError.bind(this),
    });
  }
}

export default EditGroupUtils;
