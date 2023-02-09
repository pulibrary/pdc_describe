/* eslint class-methods-use-this: ["error",
  { "exceptMethods": ["setCopiedToClipboard", "resetCopyToClipboard", "errorCopyToClipboard"] }] */

export default class CopytoClipboard {
  attach_copy() {
    // Setup the DOI's COPY button to copy the DOI URL to the clipboard
    $('#copy-doi').click(this.copy_doi.bind(this));
  }

  copy_doi() {
    var doi = $('#copy-doi').data('url');
    // value, iconEl, labelEl, normalClass, copiedClass
    this.copyToClipboard({
      value: doi,
      $icon: $('#copy-doi-icon'),
      $label: $('#copy-doi-label'),
      normalClass: 'copy-doi-label-normal',
      copiedClass: 'copy-doi-label-copied',
    });
    return false;
  }

  // Sets the elements to the proper CSS classes once a value has been copied to the clipboard.
  setCopiedToClipboard({
    $icon, $label, normalClass, copiedClass,
  }) {
    $icon.removeClass('bi-clipboard');
    $icon.addClass('bi-clipboard-check');
    $label.text('COPIED');
    $label.removeClass(normalClass);
    $label.addClass(copiedClass);
  }

  // Resets the elements to the proper CSS classes (e.g. displays as if the copy has not happened)
  resetCopyToClipboard({
    $icon, $label, normalClass, copiedClass,
  }) {
    $label.text('COPY');
    $label.removeClass(copiedClass);
    $label.addClass(normalClass);
    $icon.addClass('bi-clipboard');
    $icon.removeClass('bi-clipboard-check');
  }

  // Sets icon and label to indicate that an error happened when copying a value to the clipboard
  errorCopyToClipboard($icon, errorMsg) {
    $icon.removeClass('bi-clipboard');
    $icon.addClass('bi-clipboard-minus');
    console.log(errorMsg);
  }

  // Copies a value to the clipboard and notifies the user
  // value - value to copy to the clipboard
  // iconEl - selector for the HTML element with the clipboard icon
  // labelEl - selector for the HTML element with the COPY label next to the icon
  // normalClass - CSS to style the label with initially
  // copiedClass - CSS to style the label with after a value has been copied to the clipboard
  // iconEl and labelEl could be any jQuery valid selector (e.g. ".some-id" or a reference
  //  to an element)
  copyToClipboard({
    value, $icon, $label, normalClass, copiedClass,
  }) {
    // Copy value to the clipboard....
    navigator.clipboard.writeText(value).then(() => {
      // ...and notify the user
      this.setCopiedToClipboard({
        $icon, $label, normalClass, copiedClass,
      });
      setTimeout(() => {
        this.resetCopyToClipboard({
          $icon, $label, normalClass, copiedClass,
        });
      }, 20000);
    }, () => {
      this.errorCopyToClipboard($icon, 'Copy to clipboard failed');
    });
    // Clear focus from the button.
    document.activeElement.blur();
  }
}
