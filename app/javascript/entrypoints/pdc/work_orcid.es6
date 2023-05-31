/* eslint class-methods-use-this: ["error", { "exceptMethods": ["isOrcidFormat"] }] */

export default class WorkOrcid {
  constructor(orcidClass, givenNameKey, familyNameKey) {
    this.orcidClass = orcidClass;
    this.givenNameKey = givenNameKey;
    this.familyNameKey = familyNameKey;
  }

  attach_validation() {
    // Using $(document).on here so that the newly added rows will also pick up the event
    $(document).on('input', this.orcidClass, (el) => {
      const orcid = $(el.target).val().trim();
      const givenName = $(el.target).closest('tr').find(`input[name='${this.givenNameKey}']`);
      const familyName = $(el.target).closest('tr').find(`input[name='${this.familyNameKey}']`);
      this.fetchOrcid(orcid, givenName, familyName);
    });
  }

  // Fetch information via ORCID's public API and dumps the data into the elements indicated.
  fetchOrcid(orcidValue, givenNameId, familyNameId) {
    if (this.isOrcidFormat(orcidValue)) {
      $.ajax({
        url: `${pdc.orcid_url}/${orcidValue}`,
        dataType: 'jsonp',
      })
        .done((data) => {
          const givenName = data.person.name['given-names'].value;
          const familyName = data.person.name['family-name'].value;
          $(givenNameId).val(givenName);
          $(familyNameId).val(familyName);
        })
        .fail((XMLHttpRequest, textStatus, errorThrown) => {
          console.error(`Error fetching ORCID for ${errorThrown}`);
        });
    }
  }

  isOrcidFormat(value) {
    // Notice that we allow for an "X" as the last digit.
    // Source https://gist.github.com/asencis/644f174855899b873131c2cabcebeb87
    return /^(\d{4}-){3}\d{3}(\d|X)$/.test(value);
  }
}
