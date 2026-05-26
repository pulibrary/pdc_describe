<template>
  <div class="message-input">
    <textarea
      ref="textArea"
      v-model="message"
      placeholder="leave a message"
      rows="5"
      @keyup="findUser"
      id="new-message"
      name="new-message"
    ></textarea>
    <ul v-if="showMatches" class="match-list">
      <li
        v-for="(user, index) in matches"
        :id="`ui-id-${index}`"
        :key="user.id"
        @click="selectUser(user)"
        @keypress.enter.prevent="selectUser(user)"
        tabindex="0"
      >
        {{ user.name }} ({{ user.uid }})
      </li>
    </ul>
    <div v-if="matchError" class="error">{{ matchError }}</div>
  </div>
</template>
<script setup>
import { ref, useTemplateRef } from 'vue';

defineOptions({ name: 'MessageInput' });
const props = defineProps({
  /**
   * the current path of the files we are browsing
   */
  userLookupUrl: {
    type: String,
    required: true,
  },
  /**
   * The milliseconds to wait for more user input before sending the query
   */
  debounceTimeout: {
    type: Number,
    default: 500,
  },
});

const message = ref('');
const showMatches = ref(false);
const matchError = ref('');
const matches = ref([]);
const textAreaRef = useTemplateRef('textArea');

const debounceLoadUsers = debounce(loadUsers, props.debounceTimeout);

// Debounce function
//  this function was copied from LUX TODO: move the lux copy to a place we can access it and import it here and in lux
function debounce(func, delay) {
  let timeout;
  return function (...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => {
      func.apply(this, args);
    }, delay);
  };
}

async function loadUsers(term) {
  const result = await fetch(`${props.userLookupUrl}?term=${term}`);
  const json = await result.json();
  const users = json || [];

  if (users.length > 0) {
    showMatches.value = true;
    matches.value = users;
    matchError.value = '';
  } else {
    showMatches.value = false;
    matchError.value = 'No users found';
  }
}

async function findUser() {
  const match = queryMatch();
  if (match) {
    const searchTerm = match[1];
    await debounceLoadUsers(searchTerm);
  }
}

function selectUser(user) {
  const wordPositions = currentWord();
  const messageBeforeWord = message.value.substring(0, wordPositions.wordStart - 1);
  const messageAfterWord = message.value.substring(wordPositions.wordEnd + 1);
  message.value = messageBeforeWord;
  if (message.value.length > 0) {
    message.value += ' ';
  }
  message.value += `@${user.uid}`;
  message.value += ' ' + messageAfterWord;
  textAreaRef.value.focus();
  showMatches.value = false;
  matches.value = [];
}

function queryMatch() {
  const wordPositions = currentWord();
  const match = wordPositions.word.match(/@(\w+)$/);
  return match;
}

function currentWord() {
  const startPos = textAreaRef.value.selectionStart;
  const beforeCursor = message.value.substring(0, startPos);
  const afterCursor = message.value.substring(startPos);
  const lastSpace = beforeCursor.lastIndexOf(' ');
  const firstSpace = afterCursor.indexOf(' ');
  const wordStart = lastSpace === -1 ? 0 : lastSpace + 1;
  const wordEnd = firstSpace === -1 ? message.value.length : beforeCursor.length + firstSpace;
  return {
    wordStart: wordStart,
    wordEnd: wordEnd,
    word: message.value.substring(wordStart, wordEnd),
  };
}
</script>
<style>
.message-input {
  width: 100%;
  padding: 1rem;
  gap: 0px;
  display: flex;
  flex-direction: column;

  textarea {
    width: 100%;
  }
}
.match-list {
  list-style: none;
  padding: 0;
  margin: 0;
  border: 1px solid #ccc;
  width: 100%;
  overflow-y: auto;
}
</style>
