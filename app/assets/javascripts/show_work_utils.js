$(() => {
  // Sets the elements to the proper CSS classes once a value has been copied to the clipboard.
  function setCopiedToClipboard(iconEl, labelEl, normalClass, copiedClass) {
    $(iconEl).removeClass('bi-clipboard');
    $(iconEl).addClass('bi-clipboard-check');
    $(labelEl).text('COPIED');
    $(labelEl).removeClass(normalClass);
    $(labelEl).addClass(copiedClass);
  }

  // Resets the elements to the proper CSS classes (e.g. displays as if the copy has not happened)
  function resetCopyToClipboard(iconEl, labelEl, normalClass, copiedClass) {
    $(labelEl).text('COPY');
    $(labelEl).removeClass(copiedClass);
    $(labelEl).addClass(normalClass);
    $(iconEl).addClass('bi-clipboard');
    $(iconEl).removeClass('bi-clipboard-check');
  }

  // Sets icon and label to indicate that an error happened when copying a value to the clipboard
  function errorCopyToClipboard(iconEl, errorMsg) {
    $(iconEl).removeClass('bi-clipboard');
    $(iconEl).addClass('bi-clipboard-minus');
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
  function copyToClipboard(value, iconEl, labelEl, normalClass, copiedClass) {
    // Copy value to the clipboard....
    navigator.clipboard.writeText(value).then(() => {
      // ...and notify the user
      setCopiedToClipboard(iconEl, labelEl, normalClass, copiedClass);
      setTimeout(() => {
        resetCopyToClipboard(iconEl, labelEl, normalClass, copiedClass);
      }, 20000);
    }, () => {
      errorCopyToClipboard(iconEl, 'Copy to clipboard failed');
    });
    // Clear focus from the button.
    document.activeElement.blur();
  }

  // Setup the DOI's COPY button to copy the DOI URL to the clipboard
  $('#copy-doi').click(() => {
    var doi = $('#copy-doi').data('url');
    copyToClipboard(doi, '#copy-doi-icon', '#copy-doi-label', 'copy-doi-label-normal', 'copy-doi-label-copied');
    return false;
  });
});
