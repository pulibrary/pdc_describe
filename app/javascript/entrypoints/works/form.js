
class UploadsTable {
  constructor(root, uploads) {
    this.$root = $(root);
    this.uploads = uploads;

    this.$rows = [];
    this.buildRows();
    this.render();
  }

  reorderFiles(prevIndex, nextIndex) {

    const prev = this.uploads[prevIndex];
    const next = this.uploads[nextIndex];
    this.uploads[prevIndex] = next;
    this.uploads[nextIndex] = prev;
    this.buildRows();
    this.render();
  }

  handleDragOver(event) {
    event.preventDefault();
  }

  handleDrag(event) {
    event.preventDefault();

    const currentTarget = event.currentTarget;
    const $currentTarget = $(currentTarget);
    let $prev = $currentTarget;
    if (!$prev.hasClass('uploads-row')) {
      const $prevParents = $currentTarget.parents('.uploads-row');
      $prev = $prevParents.first();
    }

    this.$prev = $prev;
  }

  handleDrop(event) {
    event.preventDefault();

    const currentTarget = event.currentTarget;
    const $currentTarget = $(currentTarget);
    let $next = $currentTarget;
    if (!$next.hasClass('uploads-row')) {
      const $nextParents = $currentTarget.parents('.uploads-row');
      $next = $nextParents.first();
    }

    this.$next = $next;

    const prev = this.$prev.data('upload-key');
    const next = this.$next.data('upload-key');

    if (prev == next) {
      return;
    }

    this.reorderFiles(prev, next);
  }

  addEventListeners(element) {
    element.draggable = true;

    this.handleDrag = this.handleDrag.bind(this);
    element.addEventListener('drag', this.handleDrag);
    this.handleDragOver = this.handleDragOver.bind(this);
    element.addEventListener('dragover', this.handleDragOver);
    this.handleDrop = this.handleDrop.bind(this);
    element.addEventListener('drop', this.handleDrop);
  }

  buildEmptyFileElement() {
    const $fileName = $(`<td>
                           <span>
                             No files have been uploaded.
                           </span>
                         </td>`);

    const $createdAt = $(`<td><span></span></td>`);

    const $replace = $(`<td>
                        </td>`);

    const $delete = $(`<td>
                       </td>`);

    const $row = $(`<tr class="uploads-row" ></tr>`);
    $row.append($fileName);
    $row.append($createdAt);
    $row.append($replace);
    $row.append($delete);

    return $row;
  }

  buildFileElement(upload, index) {
    const downloadUrl = upload.url;
    const downloadTitle = upload.key;
    const downloadText = upload.filename;
    const $fileName = $(`<td>
                           <span>
                             <i class="bi bi-file-arrow-down"></i>
                             <a href="${downloadUrl}" class="documents-file-link" target="_blank" title="${downloadTitle}">${downloadText}</a>
                           </span>
                         </td>`);

    const createdAt = upload.created_at;
    const $createdAt = $(`<td><span>${createdAt}</span></td>`);

    const $replace = $(`<td>
                          <input id="work-deposit-uploads" name="work[replaced_uploads][${upload.id}]" type="file" />
                        </td>`);

    const $delete = $(`<td>
                         <input id="work-deposit-uploads" name="work[deleted_uploads][${upload.key}]" type="checkbox" value="1">
                       </td>`);

    const $row = $(`<tr class="uploads-row" id="uploads-${upload.id}" data-upload-key="${index}"></tr>`);
    $row.append($fileName);
    $row.append($createdAt);
    $row.append($replace);
    $row.append($delete);
    const rowElement = $row[0];
    this.addEventListeners(rowElement);

    return $row;
  }

  buildRows() {
    this.$rows = [];
    let $uploadElement;

    if (this.uploads.length > 0) {
      for (const index in this.uploads) {
        const upload = this.uploads[index];
        $uploadElement = this.buildFileElement(upload, index);
        this.$rows.push($uploadElement);
      }
    } else {
      $uploadElement = this.buildEmptyFileElement();
      this.$rows.push($uploadElement);
    }
  }

  get $tbody() {
    const $children = this.$root.children('tbody');
    const $child = $children.first();

    return $child;
  }

  render() {
    $(this.$tbody).empty();

    for (const $row of this.$rows) {
      $(this.$tbody).append($row);
    }
  }
}

class WorkForm {
  constructor(root, work) {
    this.$root = $(root);
    this.work = work;

    this.buildUploadsTable();
  }

  get $uploadsTable() {
    const $children = this.$root.find('.uploads-table');
    const $child = $children.first();

    return $child;
  }

  buildUploadsTable() {
    this.uploadsTable = new UploadsTable(this.$uploadsTable, this.work.uploads);
  }
}

export default WorkForm;
