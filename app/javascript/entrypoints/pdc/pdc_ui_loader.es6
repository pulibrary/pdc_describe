import CopytoClipboard from './copy_to_clipboard.es6';
import MaximumFileUpload from './maximum_file_upload.es6';

/* eslint class-methods-use-this: ["error", { "exceptMethods": ["setup_fileupload_validation"] }] */

export default class PdcUiLoader {
  run() {
    this.setup_fileupload_validation();
  }

  setup_fileupload_validation() {
    (new MaximumFileUpload('patch_pre_curation_uploads', 'file-upload')).attach_validation();
    (new MaximumFileUpload('pre_curation_uploads', 'btn-submit')).attach_validation();
    (new CopytoClipboard()).attach_copy();
  }
}
