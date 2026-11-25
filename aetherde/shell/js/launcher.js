import { ipc } from './ipc.js';

const $ = (id) => document.getElementById(id);
let apps = [];
let labels = {};
let activeCategory = 'All';
let query = '';
let onLaunch = () => {};

function fuzzyMatch(text, needle) {
  if (!needle) return true;
  const haystack = text.toLowerCase();
  if (haystack.includes(needle)) return true;
  let cursor = 0;
  for (const character of haystack) {
    if (character === needle[cursor]) cursor += 1;
    if (cursor === needle.length) return true;
  }
  return false;
}

function categories() {
  const present = new Set();
  apps.forEach((app) => app.categories.forEach((category) => present.add(category)));
  return ['All', ...[...present].sort()];
}

function renderCategories() {
  const container = $('app-categories');
  container.replaceChildren();
  for (const category of categories()) {
    const chip = document.createElement('button');
    chip.className = 'category-chip';
    if (category === activeCategory) chip.classList.add('active');
    chip.dataset.category = category;
    chip.textContent = labels[category] || category;
    container.append(chip);
  }
}

function renderGrid() {
  const grid = $('app-grid');
  grid.replaceChildren();
  const matches = apps.filter((app) => {
    const inCategory = activeCategory === 'All' || app.categories.includes(activeCategory);
    const searchable = `${app.name} ${app.generic_name} ${app.comment}`;
    return inCategory && fuzzyMatch(searchable, query);
  });
  for (const app of matches) {
    const tile = document.createElement('button');
    tile.className = 'app-tile';
    tile.dataset.appId = app.id;
    tile.title = app.comment || app.name;
    if (app.icon) {
      const image = document.createElement('img');
      image.src = app.icon;
      image.alt = '';
      tile.append(image);
    } else {
      const glyph = document.createElement('span');
      glyph.className = 'app-glyph';
      glyph.textContent = app.name.slice(0, 1).toUpperCase();
      tile.append(glyph);
    }
    const label = document.createElement('span');
    label.textContent = app.name;
    tile.append(label);
    grid.append(tile);
  }
  if (!matches.length) {
    const empty = document.createElement('p');
    empty.className = 'qs-line';
    empty.textContent = 'No applications match this search.';
    grid.append(empty);
  }
}

export function openLauncher() {
  $('launcher').classList.remove('hidden');
  const search = $('app-search');
  search.value = '';
  query = '';
  renderGrid();
  search.focus();
}

export function closeLauncher() {
  $('launcher').classList.add('hidden');
}

export async function initLauncher(options = {}) {
  onLaunch = options.onLaunch || onLaunch;
  $('btn-launcher').addEventListener('click', openLauncher);
  $('launcher-close').addEventListener('click', closeLauncher);
  $('launcher').addEventListener('click', (event) => {
    if (event.target === $('launcher')) closeLauncher();
  });
  $('app-search').addEventListener('input', (event) => {
    query = event.target.value.trim().toLowerCase();
    renderGrid();
  });
  $('app-categories').addEventListener('click', (event) => {
    const chip = event.target.closest('[data-category]');
    if (!chip) return;
    activeCategory = chip.dataset.category;
    renderCategories();
    renderGrid();
  });
  $('app-grid').addEventListener('click', (event) => {
    const tile = event.target.closest('[data-app-id]');
    if (!tile) return;
    const app = apps.find((item) => item.id === tile.dataset.appId);
    if (app) {
      closeLauncher();
      onLaunch(app);
    }
  });

  const data = await ipc.api('/api/apps');
  apps = data.apps;
  labels = data.categories;
  renderCategories();
  renderGrid();
}
