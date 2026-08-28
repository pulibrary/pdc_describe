<template>
  <div class="work-citation">
    <div>Cite as:</div>
    <lux-tab-wrapper class="citation-tab-wrapper" id="citation-tab-wrapper">
      <lux-tab title="Text">
        <div class="citation-wrapper">
          <div>{{ textCitation }}</div>
          <div>
            <div class="copy-wrapper">
              <lux-copy-to-clipboard id="apa-clip" :clipboard-value="textCitation">
              </lux-copy-to-clipboard>
            </div>
            <span class="copy-citation-label-normal">Copy</span>
          </div>
        </div>
      </lux-tab>
      <lux-tab title="BibTeX">
        <div class="citation-wrapper">
          <div>{{ bibtexCitation }}</div>
          <div class="actions">
            <div>
              <div class="copy-wrapper">
                <lux-copy-to-clipboard id="bibtex-clip" :clipboard-value="bibtexCitation">
                </lux-copy-to-clipboard>
              </div>
              <span class="copy-citation-label-normal">Copy</span>
            </div>
            <button
              class="btn btn-sm"
              title="Download BibTeX citation to a file"
              @click="download()"
            >
              <i class="bi bi-file-arrow-down" title="Download BibTeX citation to a file"></i>
              <span class="copy-citation-label-normal">DOWNLOAD</span>
            </button>
          </div>
        </div>
      </lux-tab>
    </lux-tab-wrapper>
  </div>
</template>
<script setup>
import { ref, useTemplateRef } from 'vue';
import { LuxCopyToClipboard, LuxTabWrapper, LuxTab } from 'lux-design-system';

defineOptions({ name: 'WorkCitation' });
const props = defineProps({
  /**
   * The apa style citation for the work
   */
  textCitation: {
    type: String,
    required: true,
  },
  /**
   * The BibTeX citation for the work
   */
  bibtexCitation: {
    type: String,
    required: true,
  },
  /**
   * The BibTeX download URL for the work
   */
  bibtexDownloadUrl: {
    type: String,
    required: true,
  },
});

function download() {
  window.location.href = props.bibtexDownloadUrl;
}
</script>
<style>
.actions {
  display: flex;
  gap: 0.5rem;
}

.copy-wrapper {
  display: flex;
  align-items: center;
}

.work-citation {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding-bottom: 1rem;
}

.citation-tab-wrapper {
  ul li {
    list-style-type: none;
  }
}

.citation-wrapper {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
</style>
