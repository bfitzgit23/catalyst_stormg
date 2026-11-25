import { ipc } from './ipc.js';

const $ = (id) => document.getElementById(id);

class FloatingTerminal {
  constructor() {
    this.ready = false;
    this.id = null;
    this.term = null;
    this.fit = null;
  }

  async init() {
    if (this.ready) return;
    const [{ Terminal }, { FitAddon }] = await Promise.all([
      import('/vendor/xterm/xterm.js'),
      import('/vendor/xterm-fit/addon-fit.js'),
    ]);
    this.term = new Terminal({
      cursorBlink: true,
      fontSize: 13,
      lineHeight: 1.25,
      fontFamily: '"JetBrains Mono", "DejaVu Sans Mono", monospace',
      allowTransparency: true,
      theme: {
        background: 'rgba(10, 13, 24, 0.92)',
        foreground: '#e6ebff',
        cursor: '#6ea8fe',
        selectionBackground: 'rgba(110, 168, 254, 0.32)',
        black: '#1b2030', red: '#ff6b6b', green: '#51cf66', yellow: '#fcc419',
        blue: '#6ea8fe', magenta: '#b197fc', cyan: '#66d9e8', white: '#e6ebff',
      },
    });
    this.fit = new FitAddon();
    this.term.loadAddon(this.fit);
    this.term.open($('terminal-body'));

    ipc.on('pty:spawned', (message) => {
      this.id = message.id;
      this.fit.fit();
      this.term.focus();
    });
    ipc.on('pty:output', (message) => {
      if (message.id === this.id) this.term.write(message.data);
    });
    ipc.on('pty:exit', (message) => {
      if (message.id === this.id) {
        this.term.write(`\r\n\x1b[2m[process exited: ${message.exitCode}]\x1b[0m\r\n`);
        this.id = null;
      }
    });

    this.term.onData((data) => {
      if (this.id) ipc.send('pty', { type: 'input', id: this.id, data });
    });
    this.term.onResize(({ cols, rows }) => {
      if (this.id) ipc.send('pty', { type: 'resize', id: this.id, cols, rows });
    });

    this.bindControls();
    this.ready = true;
  }

  bindControls() {
    const windowElement = $('terminal-window');
    const titlebar = $('terminal-titlebar');
    let dragging = false;
    let offsetX = 0;
    let offsetY = 0;

    titlebar.addEventListener('pointerdown', (event) => {
      if (event.target.closest('button')) return;
      dragging = true;
      offsetX = event.clientX - windowElement.offsetLeft;
      offsetY = event.clientY - windowElement.offsetTop;
      titlebar.setPointerCapture(event.pointerId);
    });
    titlebar.addEventListener('pointermove', (event) => {
      if (!dragging) return;
      windowElement.style.left = `${Math.max(0, event.clientX - offsetX)}px`;
      windowElement.style.top = `${Math.max(0, event.clientY - offsetY)}px`;
    });
    titlebar.addEventListener('pointerup', () => { dragging = false; });

    $('term-min').addEventListener('click', () => windowElement.classList.add('hidden'));
    $('term-close').addEventListener('click', () => {
      if (this.id) ipc.send('pty', { type: 'kill', id: this.id });
      this.id = null;
      windowElement.classList.add('hidden');
    });
    window.addEventListener('resize', () => {
      if (!windowElement.classList.contains('hidden') && this.fit) this.fit.fit();
    });
  }

  async open() {
    await this.init();
    const windowElement = $('terminal-window');
    windowElement.classList.remove('hidden');
    if (!this.id) {
      this.fit.fit();
      ipc.send('pty', {
        type: 'spawn',
        cols: this.term.cols,
        rows: this.term.rows,
      });
    } else {
      this.fit.fit();
      this.term.focus();
    }
  }

  async runCommand(command) {
    await this.open();
    if (this.id) ipc.send('pty', { type: 'input', id: this.id, data: `${command}\n` });
  }
}

export const terminal = new FloatingTerminal();
