$(function() {

  // Issues the HTTP DELETE to remove a user's access from a collection
  var deleteUserFromCollection = function(el, url, uid) {
    $.ajax({
      type: "DELETE",
      url: url.replace("uid-placeholder", uid),
      data: { authenticity_token: "<%= form_authenticity_token %>" },
      success: function() {
        // Remove the <li> for the user
        $(".li-user-" + uid).remove();
      },
      error: function(x) {
        alert(x.responseJSON.message);
      }
    });
  }

  // Adds the information for a given user to the lists of administrators/submitters
  // for the collection.
  // `elList` is the reference to the <ul> HTML element that hosts the list.
  var addUserHtml = function(elList, uid, collectionId, role, canDelete, isYou, is_super_admin) {
    var base_user_url = "<%= user_path('user-placeholder') %>";
    var show_user_url = base_user_url.replace("user-placeholder", uid);
    var html = `<li class="li-user-${uid}"> <a href="${show_user_url}">${uid}</a>`;
    if (isYou == true) {
      html += ` (you)`;
    }
    if (is_super_admin == true) {
      html += ` <i title="This is a system administrator, access cannot be changed." class="bi bi-person-workspace"></i>`;
    }
    if (canDelete == true) {
      html += `
        <span>
        <a class="delete-user-from-collection" data-collection-id="${collectionId}" data-uid="${uid}"
          href="#" title="Revoke user's ${role} access this collection">
          <i class="bi bi-trash delete_icon" data-collection-id="${collectionId}" data-uid="${uid}"></i>
        </a>
      </span>`;
    }
    $(elList).append(html);
  }

  // Issues the HTTP POST to add a user to a collection and updates the UI
  var addUserToCollection = function(url, elTxt, elError, elList, role) {
    var collectionId = "<%= @collection.id %>";
    var uid = $(elTxt).val().trim();
    if (uid == "") {
      $(elError).text("Enter netid of user to add");
      return;
    }

    $.ajax({
      type: "POST",
      url: url.replace("uid-placeholder", uid),
      data: { authenticity_token: "<%= form_authenticity_token %>" },
      success: function() {
        $(elTxt).val("");
        $(elError).text("");
        var canDelete = true;
        var isYou = false;
        var is_super_admin = false;
        addUserHtml(elList, uid, collectionId, role, canDelete, isYou, is_super_admin);
      },
      error: function(x) {
        $(elError).text(x.responseJSON.message);
      }
    });
  }

  // Adds a submitter to the collection
  $("#btn-add-submitter").on("click", function(x) {
    var url = '<%= add_submitter_url(id: @collection.id, uid: "uid-placeholder") %>';
    addUserToCollection(url, "#submitter-uid-to-add", "#add-submitter-message", "#submitter-list", "submit");
    $("#submitter-uid-to-add").focus();
    return false;
  });

  // Adds an administrator to the collection
  $("#btn-add-admin").on("click", function(x) {
    var url = '<%= add_admin_url(id: @collection.id, uid: "uid-placeholder") %>';
    addUserToCollection(url, "#admin-uid-to-add", "#add-admin-message", "#curator-list", "admin");
    $("#admin-uid-to-add").focus();
    return false;
  });

  if ($("#data-loaded").text() != "true") {
    // Displays the initial list of submitters.
    $(".submitter-data").each(function(ix, el) {
      var elList = $("#submitter-list");
      var uid = $(el).data("uid");
      var collectionId = $(el).data("collectionId");
      var canDelete = $(el).data("canDelete");
      var isYou = $(el).data("you") == true;
      var is_super_admin = false;
      addUserHtml(elList, uid, collectionId, "submit", canDelete, isYou, is_super_admin);
    });

    // Displays the initial list of curators.
    $(".curator-data").each(function(ix, el) {
      var elList = $("#curator-list");
      var uid = $(el).data("uid");
      var collectionId = $(el).data("collectionId");
      var canDelete = $(el).data("canDelete");
      var isYou = $(el).data("you") == true;
      addUserHtml(elList, uid, collectionId, "admin", canDelete, isYou, false);
    });

    // Displays the list of system administrators.
    $(".sysadmin-data").each(function(ix, el) {
      var elList = $("#sysadmin-list");
      var uid = $(el).data("uid");
      var collectionId = $(el).data("collectionId");
      var isYou = $(el).data("you") == true;
      addUserHtml(elList, uid, collectionId, "admin", false, isYou, true);
    });

    // Track that we have displayed this information. This prevents re-display when
    // user click the Back/Forward button on their browser.
    $('<span id="data-loaded" class="hidden">true</span>').appendTo("body");
  }

  // Wire up the delete button for all users listed in the collection.
  //
  // Notice the use of $(document).on("click", selector, ...) instead of the
  // typical $(selector).on("click", ...). This syntax is required so that
  // we can detect the click even on HTML elements _added on the fly_ which
  // is the case when a user adds a new submitter or admin to the collection.
  // Reference: https://stackoverflow.com/a/17086311/446681
  $(document).on("click", ".delete-user-from-collection", function(el) {
    var url = '<%= delete_user_from_collection_url(id: @collection.id, uid: "uid-placeholder") %>'
    var uid = $(el.target).data("uid");
    var message = "Revoke access to user " + uid;
    if (confirm(message)) {
      deleteUserFromCollection(el, url, uid);
    }
    return false;
  });
});
