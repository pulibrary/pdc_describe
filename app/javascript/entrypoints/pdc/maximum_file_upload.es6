export default class MaximumFileUpload {
  constructor(upload_id, save_id, error_id = 'file-error') {
    this.upload_element = $(`#${upload_id}`);
    this.save_element = document.getElementById(save_id);
    this.error_element = document.getElementById(error_id);
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
