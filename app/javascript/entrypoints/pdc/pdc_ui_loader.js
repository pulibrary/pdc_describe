import MaximumFileUpload from './maximum_file_upload';

export default class PdcUiLoader {
  run() {
    new MaximumFileUpload('patch_pre_curation_uploads', 'file-upload');
    new MaximumFileUpload('pre_curation_uploads', 'btn-submit');
  }
}
