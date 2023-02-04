import MaximumFileUpload from './maximum_file_upload.js';

export default class PdcUiLoader {
  run() {
    this.setup_fileupload_validation();
  }

  setup_fileupload_validation() {
    new MaximumFileUpload('patch_pre_curation_uploads', 'file-upload');
    new MaximumFileUpload('pre_curation_uploads', 'btn-submit');
  }
}
