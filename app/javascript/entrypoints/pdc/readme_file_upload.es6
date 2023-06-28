export default class ReadmeFileUpload {
  constructor(uploadId, saveId, errorId = 'file-error') {
    this.upload_element = $(`#${uploadId}`);
    this.save_element = document.getElementById(saveId);
    this.error_element = document.getElementById(errorId);
  }

  attach_validation() {
    this.upload_element.on('change', this.validate.bind(this));
  }

  validate() {
    if (this.upload_element[0].files.length < 1) {
      this.save_element.disabled = true;
      this.error_element.innerText = 'You must select a README file';
    } else {
      const filename = this.upload_element[0].files[0].name.toLowerCase();
      if (filename.includes("readme") == true) {
        this.save_element.disabled = false;
        this.error_element.innerText = '';
      } else {
        this.save_element.disabled = true;
        this.error_element.innerText = 'You must select a file that includes the word README in the name (lowercase or uppercase is accepted)';
      }
    }
  }
}
