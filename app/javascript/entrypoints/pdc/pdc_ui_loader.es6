import CopytoClipboard from './copy_to_clipboard.es6';
import MaximumFileUpload from './maximum_file_upload.es6';
import EditRequiredFields from './edit_required_fields.es6';
import ReadmeFileUpload from './readme_file_upload.es6';
import WorkOrcid from './work_orcid.es6';
import WorkRoR from './work_ror.es6';

/* eslint class-methods-use-this: ["error", { "exceptMethods": ["setup_fileupload_validation"] }] */

export default class PdcUiLoader {
  run() {
    this.setup_fileupload_validation();
  }

  setup_fileupload_validation() {
    (new MaximumFileUpload('patch_pre_curation_uploads', 'file-upload')).attach_validation();
    (new MaximumFileUpload('pre_curation_uploads_added', 'btn-submit')).attach_validation();
    (new CopytoClipboard()).attach_copy();
    (new EditRequiredFields()).attach_validations();
    (new ReadmeFileUpload('patch_readme_file', 'readme-upload')).attach_validation();
    (new WorkOrcid('.orcid-entry-creator', 'given_name_', 'family_name_')).attach_validation();
    (new WorkOrcid('.orcid-entry-collaborator', 'contributor_given_name_', 'contributor_family_name_')).attach_validation();
    (new WorkRoR(pdc.ror_url)).attach_query();
  }
}
