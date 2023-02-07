export default class MaximumFileUpload {
  constructor(uploadId, saveId, errorId = 'file-error') {
    this.upload_element = $(`#${uploadId}`);
    this.save_element = document.getElementById(saveId);
    this.error_element = document.getElementById(errorId);
  }

  attach_validation() {
    console.log('attaching validation');
    this.upload_element.on('change', this.validate.bind(this));
  }

  validate() {
    if (this.upload_element[0].files.length > 20) {
      this.save_element.disabled = true;
      this.error_element.innerText = 'You can select a maximum of 20 files';
    } else {
      this.save_element.disabled = false;
      this.error_element.innerText = '';
    }
  }
}
