function isOrcid(value) {
  // Notice that we allow for an "X" as the last digit.
  // Source https://gist.github.com/asencis/644f174855899b873131c2cabcebeb87
  return /^(\d{4}-){3}\d{3}(\d|X)$/.test(value)
};

window.isOrcid = isOrcid;

export { isOrcid };