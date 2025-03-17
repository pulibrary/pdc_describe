/* global Uppy */
export default class WorkEditFileUpload {
  constructor(fileUploadId, fileListId) {
    this.file_upload_element = $(`#${fileUploadId}`);
    this.file_list_element = $(`#${fileListId}`);
  }

  attach_validation() {
    const uploadUrl = $('#uppy_upload_url').text();
    this.file_upload_element.on('change', this.validate.bind(this));
    if (uploadUrl !== '') {
      WorkEditFileUpload.setupUppy(uploadUrl);
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
  static setupUppy(uploadUrl) {
    // https://uppy.io/blog/2018/08/0.27/#autoproceed-false-by-default
    // https://uppy.io/docs/uppy/#restrictions
    const uppy = Uppy.Core({
      autoProceed: true,
      restrictions: { maxNumberOfFiles: 20 },
    });

    // Configure the initial display (https://uppy.io/docs/dashboard)
    uppy.use(Uppy.Dashboard, {
      target: '#file-upload-area',
      inline: false, // display of dashboard only when trigger is clicked
      trigger: '#add-files-button',
    });

    // We use the XHRUploader, this is the most basic uploader (https://uppy.io/docs/xhr-upload/)
    // X-CSRF-Token: https://stackoverflow.com/a/75050497/446681
    const token = document.querySelector("meta[name='csrf-token']");
    let tokenContent;
    if (token) {
      tokenContent = token.content;
    } else {
      tokenContent = '';
    }
    uppy.use(Uppy.XHRUpload, {
      endpoint: uploadUrl,
      headers: { 'X-CSRF-Token': tokenContent },
      bundle: true, // upload all selected files at once
      formData: true, // required when bundle: true
      getResponseData(serverResponse) {
        try {
          // A normal response is a string that can be parsed as JSON
          response = JSON.parse(serverResponse)
          // Reload the file list displayed
          const fileTable = $('#files-table').dataTable();
          fileTable.api().ajax.reload();
        } catch (ex) {

          // Display the error message to the user
          var errorMessage;
          if ((serverResponse || "").toLowerCase().includes("your support id")) {
            // We could not parse the serverResponse and it includes "Your support" ID
            // we assume the problem is the Load Balancer.
            errorMessage = "Error uploading file: Our load balancer rejected the request.";
          } else {
            // Any other kind of error.
            errorMessage = `Error uploading file: ${ex.message}`;
          }

          uppy.info(errorMessage, "error", 10000);

          // Remove the files from the Uppy dashboard so that Uppy does not show
          // the file in green to the user because that makes the user experience
          // very confusing: the is file shown in green with a red error message.
          //
          // A side effect of removing the files from Uppy is that the Browser's
          // console will log "Uncaught TypeError: e.getFile(...) is undefined"
          // but we can safely ignore that error message since we are indeed cancelling
          // the file upload.
          var files = uppy.getFiles();
          var i, file;
          for(i = 0; i < files.length; i += 1) {
            file = files[i];
            if (file.progress.uploadComplete === false) {
              uppy.removeFile(file.id);
            }
          }

        }
      },
    });

    // Prevent the button's click from submitting the form since the
    // files' payload is automatically submitted by Uppy
    $('#add-files-button').on('click', () => false);
  }
}
