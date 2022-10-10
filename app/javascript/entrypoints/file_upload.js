$(document).ready(() => {
  addEventListener("direct-uploads:initialize", (event) => {
    const { target, detail } = event;
    const { id, file } = detail;

    target.insertAdjacentHTML(
      "beforebegin",
      `
      <div id="direct-upload-${id}" class="direct-upload direct-upload--pending">
        <i style="font-size: 50px;" class="bi bi-paperclip"></i><p>Please attach your submission of under 100GB here.</p>
        <div id="direct-upload-progress-${id}" class="direct-upload__progress" style="width: 0%"></div>
        <span class="direct-upload__filename"></span>
      </div>
    `
    );

    target.previousElementSibling.querySelector(
      `.direct-upload__filename`
    ).textContent = file.name;
  });
});
