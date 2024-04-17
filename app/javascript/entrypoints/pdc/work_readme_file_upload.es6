/* global Uppy */
export default class WorkReadmeFileUpload {
  constructor(triggerButtonId, uppyAreaId) {
    this.triggerButtonId = triggerButtonId;
    this.uppyAreaId = uppyAreaId;
  }

  attach_validation() {
    const uploadUrl = $('#uppy_upload_url').text();
    if (uploadUrl !== '') {
      WorkReadmeFileUpload.setupUppy(this.triggerButtonId, this.uppyAreaId, uploadUrl );
    }
  }

  // Setup Uppy to handle file uploads
  // References:
  //    https://uppy.io/docs/quick-start/
  //    https://davidwalsh.name/uppy-file-uploading
  static setupUppy(triggerButtonId, uppyAreaId, uploadUrl) {
    // https://uppy.io/blog/2018/08/0.27/#autoproceed-false-by-default
    // https://uppy.io/docs/uppy/#restrictions
    const uppy = Uppy.Core({
      autoProceed: true,
      restrictions: {
        maxNumberOfFiles: 1,
        allowedFileTypes: ['.txt', '.md'],
      },
      onBeforeUpload(files) {
        // source: https://github.com/transloadit/uppy/issues/1703#issuecomment-507202561
        if (Object.entries(files).length === 1) {
          const file = Object.entries(files)[0][1];
          if (file.meta.name.toLowerCase().includes("readme") === true) {
            // we are good
            return true;
          }
        }
        uppy.info('You must select a file that includes the word README in the name', 'error');
        return false;
      },
    });

    // Configure the initial display (https://uppy.io/docs/dashboard)
    uppy.use(Uppy.Dashboard, {
      target: `#${uppyAreaId}`,
      inline: false, // display of dashboard only when trigger is clicked
      trigger: `#${triggerButtonId}`,
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
        $('#readme-upload').prop('disabled', false);
      },
    });

    // Prevent the button's click from submitting the form since the
    // files' payload is automatically submitted by Uppy
    $(`#${triggerButtonId}`).on('click', () => false);
  }
}
