/* global Uppy */
export default class WorkReadmeFileUpload {
  constructor(triggerButtonId, uppyAreaId, maxFiles) {
    this.triggerButtonId = triggerButtonId;
    this.uppyAreaId = uppyAreaId;
    this.maxFiles = maxFiles;
  }

  attach_validation() {
    const uploadUrl = $('#uppy_upload_url').text();
    if (uploadUrl !== '') {
      WorkReadmeFileUpload.setupUppy(this.triggerButtonId, this.uppyAreaId, this.maxFiles, uploadUrl);
    }
  }

  // Setup Uppy to handle file uploads
  // References:
  //    https://uppy.io/docs/quick-start/
  //    https://davidwalsh.name/uppy-file-uploading
  static setupUppy(triggerButtonId, uppyAreaId, maxFiles, uploadUrl) {
    // https://uppy.io/blog/2018/08/0.27/#autoproceed-false-by-default
    // https://uppy.io/docs/uppy/#restrictions
    const uppy = Uppy.Core({
      autoProceed: true,
      restrictions: {
        maxNumberOfFiles: maxFiles,
        allowedFileTypes: ['.txt', '.md'],
      },
    });

    // Configure the initial display (https://uppy.io/docs/dashboard)
    uppy.use(Uppy.Dashboard, {
      target: '#' + uppyAreaId,
      inline: false, // display of dashboard only when trigger is clicked
      trigger: '#' + triggerButtonId,
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
      getResponseData(filename) {
        $('#new-readme').html(`File <b>${filename}</b> has been uploaded and set as the README for this dataset.`);
        $('#readme-upload').prop("disabled", false);
      },
    });

    // Prevent the button's click from submitting the form since the
    // files' payload is automatically submitted by Uppy
    $('#' + triggerButtonId).on('click', () => false);
  }
}
