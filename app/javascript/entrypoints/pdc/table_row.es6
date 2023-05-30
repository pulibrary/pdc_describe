export default class TableRow {
  constructor(row) {
    this.row = row;
  }

  is_empty() {
    let isEmptyRow = true;
    const inputs = $(this.row).find('input');
    for (const input of inputs) {
      if (input.value !== '') {
        isEmptyRow = false;
        break;
      }
    }
    return isEmptyRow;
  }
}
