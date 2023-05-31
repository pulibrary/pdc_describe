import CopytoClipboard from './copy_to_clipboard.es6';
import MaximumFileUpload from './maximum_file_upload.es6';
import EditRequiredFields from './edit_required_fields.es6';
import ReadmeFileUpload from './readme_file_upload.es6';
import WorkOrcid from './work_orcid.es6';
import WorkRoR from './work_ror.es6';
import EditTableActions from './edit_table_actions.es6';

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
    (new WorkOrcid('.orcid-entry-creator', 'creators[][given_name]', 'creators[][family_name]')).attach_validation();
    (new WorkOrcid('.orcid-entry-contributor', 'contributors[][given_name]', 'contributors[][family_name]')).attach_validation();
    (new WorkRoR(pdc.ror_url)).attach_query();
    (new EditTableActions()).attach_actions();
  }
}
