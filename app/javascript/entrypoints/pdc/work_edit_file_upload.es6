export default class WorkEditFileUpload {
  constructor(fileUploadId, fileListId) {
    this.file_upload_element = $(`#${fileUploadId}`);
    this.file_list_element = $(`#${fileListId}`);
  }

  attach_validation() {
    this.file_upload_element.on('change', this.validate.bind(this));
  }

  validate() {
    const files = this.file_upload_element[0].files;
    if (files.length <= 1) {
      // Zero or 1 files: let the browser display the default information
      this.file_list_element.html('');
    } else {
      // More than one file: display a list of files
      var html = '<ul>';
      for(var i=0; i<files.length; i++) {
        html += `<li>${files[i].name}`
      }
      html += '</ul>'
      this.file_list_element.html(html);
    }
  }
}
