import { ipc } from './ipc.js';

const $ = (id) => document.getElementById(id);
const store = new Map();

function makeCard(note, toast = false) {
  const card = document.createElement('div');
  card.className = toast ? 'toast' : 'notification';

  const app = document.createElement('div');
  app.className = 'n-app';
  app.textContent = note.app_name || 'Notification';
  card.append(app);

  const summary = document.createElement('div');
  summary.className = 'n-summary';
  summary.textContent = note.summary || '';
  card.append(summary);

  if (note.body) {
    const body = document.createElement('div');
    body.className = 'n-body';
    body.textContent = note.body;
    card.append(body);
  }

  if (!toast) {
    const close = document.createElement('button');
    close.className = 'n-close';
    close.textContent = '×';
    close.title = 'Dismiss';
    close.addEventListener('click', () => {
      store.delete(note.id);
      renderCenter();
    });
    card.append(close);
  }
  return card;
}

function renderCenter() {
  const list = $('notif-list');
  list.replaceChildren();
  for (const note of [...store.values()].reverse()) list.append(makeCard(note));
  const badge = $('notif-badge');
  badge.textContent = String(store.size);
  badge.classList.toggle('hidden', store.size === 0);
}

function showToast(note) {
  const toast = makeCard(note, true);
  $('toast-stack').prepend(toast);
  const lifetime = note.expire_timeout > 0 ? note.expire_timeout : 5000;
  setTimeout(() => toast.remove(), Math.min(lifetime, 15000));
}

function add(note) {
  if (!note) return;
  store.set(note.id, note);
  renderCenter();
  showToast(note);
}

export function initNotifications() {
  ipc.on('notification', add);
  ipc.on('notification_close', (message) => {
    store.delete(message.id);
    renderCenter();
  });
  $('notif-clear').addEventListener('click', () => {
    store.clear();
    renderCenter();
  });
  renderCenter();
}
