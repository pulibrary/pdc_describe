export default class WorkRoR {
  constructor(rorUrl) {
    this.rorUrl = rorUrl;
  }

  attach_query() {
    // Using $(document).on here so that the newly added rows will also pick up the event
    $(document).on('change', '.ror-input', (el) => {
      this.fetchROR(el);
    });
  }

  // Fetch information for funder via the ROR API
  fetchROR(element) {
    const $target = $(element.target);
    const ror = $target.val().trim();

    fetch(`${this.rorUrl}/${ror}`)
    .then(response => {
        return response.json();
    })
    .then(data => {
        const name = data["names"].filter((names) => names.types.includes("ror_display"))[0].value;
        $target.closest('tr').find('.ror-output').val(name);
    })
    .catch(error => {
        console.error('Fetch error:', error);
    });

    // fetch(`${this.rorUrl}/${ror}`)
    //   .then()
    //   .then((response) => response.json())
    //   .then((responseJson) => {
    //     const { name } = responseJson;
    //     $target.closest('tr').find('.ror-output').val(name);
    //   });
  }
}
