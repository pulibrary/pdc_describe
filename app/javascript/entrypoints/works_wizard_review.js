class WorksWizardReview {
  static bind(elementSelector) {
    let built;
    const root = document.querySelector(elementSelector);

    if (root) {
      built = new WorksWizardReview(root);
    }

    return built;
  }

  static handleClick(event) {
    const message = "You're about to grant license for this dataset. Are you sure?";
    const input = window.confirm(message);

    if (input === false) {
      event.preventDefault();
    }
  }

  constructor(root) {
    this.root = root;

    if (this.root) {
      const handleClick = WorksWizardReview.handleClick.bind(this);
      this.root.addEventListener('click', handleClick);
    }
  }
}

export default WorksWizardReview;
