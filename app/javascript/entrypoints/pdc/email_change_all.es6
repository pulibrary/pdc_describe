/* eslint class-methods-use-this: ["error",
  { "exceptMethods": ["change_all", "change_subcommunity", "change_parent_group"] }] */
/* eslint-disable no-param-reassign */
export default class EmailChangeAll {
  attach_change() {
    // Setup the DOI's COPY button to copy the DOI URL to the clipboard
    document.querySelectorAll('.form-email-all').forEach((check) =>
      check.addEventListener('change', (e) => {
        this.change_all(e);
      }),
    );
    document.querySelectorAll('.form-subcommunity-check').forEach((check) =>
      check.addEventListener('change', (e) => {
        this.change_parent_group(e);
      }),
    );
    document.querySelectorAll('.form-group-check').forEach((check) =>
      check.addEventListener('change', (e) => {
        this.change_subcommunity(e);
      }),
    );
  }

  change_all(item) {
    // Check all or uncheck all
    document.querySelectorAll('.form-check-input').forEach((check) => {
      check.checked = item.currentTarget.checked;
    });
  }

  change_subcommunity(item) {
    item.currentTarget.parentNode.querySelectorAll('.form-check-input').forEach((check) => {
      check.checked = item.currentTarget.checked;
    });

    // make sure the all email is enabled if any sub group is enabled
    if (item.currentTarget.checked) {
      document.querySelector('.form-email-all').checked = item.currentTarget.checked;
    }
  }

  change_parent_group(item) {
    // make sure all email and = the parent group is enabled if any sub community is enabled
    if (item.currentTarget.checked) {
      item.currentTarget.parentNode.parentNode.parentNode
        .querySelectorAll('.form-group-check')
        .forEach((check) => {
          check.checked = item.currentTarget.checked;
        });
      document.querySelector('.form-email-all').checked = item.currentTarget.checked;
    }
  }
}
/* eslint-enable no-param-reassign */
