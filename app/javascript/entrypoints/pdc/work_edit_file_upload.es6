export default class WorkEditFileUpload {
  constructor(fileUploadId, fileListId) {
    this.file_upload_element = $(`#${fileUploadId}`);
    this.file_list_element = $(`#${fileListId}`);
  }

  attach_validation() {
    const uploadUrl = $('#uppy_upload_url').text();
    this.file_upload_element.on('change', this.validate.bind(this));
    if (uploadUrl !== '') {
      this.setupUppy(uploadUrl);
    }
  }

  validate() {
    let html;
    const files = this.file_upload_element[0];
    if (files.length <= 1) {
      // Zero or 1 files: let the browser display the default information
      this.file_list_element.html('');
    } else {
      // More than one file: display a list of files
      html = '<ul>';
      for (let i = 0; i < files.length; i += 1) {
        html += `<li>${files[i].name}`;
      }
      html += '</ul>';
      this.file_list_element.html(html);
    }
  }

  // Setup Uppy to handle file uploads
  // References:
  //    https://uppy.io/docs/quick-start/
  //    https://davidwalsh.name/uppy-file-uploading
  setupUppy(uploadUrl) {
    // https://uppy.io/blog/2018/08/0.27/#autoproceed-false-by-default
    const uppy = Uppy.Core({ autoProceed: true });

    // Configure the initial display (https://uppy.io/docs/dashboard)
    uppy.use(Uppy.Dashboard, {
      target: '#file-upload-area',
      inline: false, // display of dashboard only when trigger is clicked
      trigger: '#add-files-button',
    });

    // We use the XHRUploader, this is the most basic uploader (https://uppy.io/docs/xhr-upload/)
    // X-CSRF-Token: https://stackoverflow.com/a/75050497/446681
    uppy.use(Uppy.XHRUpload, {
      endpoint: uploadUrl,
      headers: { 'X-CSRF-Token': document.querySelector("meta[name='csrf-token']").content },
      bundle: true,   // upload all selected files at once
      formData: true, // required when bundle: true
      getResponseData: function(responseText, response) {
        // Reload the file list displayed
        let fileTable = $('#files-table').dataTable();
        fileTable.api().ajax.reload();
      },
    });

    $('#add-files-button').on('click', function() {
      // Prevent the button's click from submitting the form since the
      // files' payload is automatically submitted by Uppy
      return false;
    });
  }
}
