class WorksWizardPolicy {
  static bind(elementSelector) {
    let built;
    const root = document.querySelector(elementSelector);

    if (root) {
      built = new WorksWizardPolicy(root, '#submit-button');
    }

    return built;
  }

  handleChange(event) {
    const { classList } = this.submitButton;

    if (event.target.checked) {
      classList.remove('btn-secondary');
      classList.remove('disabled');
      classList.add('btn-primary');

      this.submitButton.disabled = false;
    } else {
      classList.remove('btn-primary');
      classList.add('disabled');
      classList.add('btn-secondary');

      this.submitButton.disabled = true;
    }
  }

  constructor(root, buttonSelector) {
    this.root = root;
    this.submitButton = null;

    if (this.root) {
      const submitButton = document.querySelector(buttonSelector);

      if (submitButton) {
        this.submitButton = submitButton;
        const handleChange = this.handleChange.bind(this);
        this.root.addEventListener('change', handleChange);
      }
    }
  }
}

export default WorksWizardPolicy;
