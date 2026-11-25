'use strict';
// node-pty multiplexer. term.resize() issues TIOCSWINSZ on the PTY master and
// propagates SIGWINCH to the foreground process group — no polling involved.

const fs = require('fs');
const os = require('os');
const { randomUUID } = require('crypto');
const pty = require('node-pty');

function defaultShell() {
  if (process.env.SHELL && fs.existsSync(process.env.SHELL)) return process.env.SHELL;
  for (const candidate of ['/usr/bin/zsh', '/bin/zsh', '/usr/bin/bash', '/bin/bash']) {
    if (fs.existsSync(candidate)) return candidate;
  }
  return '/bin/sh';
}

class PtyMultiplexer {
  constructor() {
    this.sessions = new Map();
  }

  create(ws, options = {}) {
    const id = randomUUID();
    const shell = options.shell && fs.existsSync(options.shell)
      ? options.shell
      : defaultShell();
    const cols = Math.max(20, Math.min(400, Number(options.cols) || 80));
    const rows = Math.max(5, Math.min(200, Number(options.rows) || 24));
    const cwd = options.cwd && fs.existsSync(options.cwd) ? options.cwd : os.homedir();

    const term = pty.spawn(shell, [], {
      name: 'xterm-256color',
      cols,
      rows,
      cwd,
      env: {
        ...process.env,
        TERM: 'xterm-256color',
        COLORTERM: 'truecolor',
        AETHER_TERM: id,
      },
    });

    const session = { id, term, ws, alive: true };
    term.onData((data) => {
      if (session.alive && ws.readyState === 1) {
        ws.send(JSON.stringify({ channel: 'pty', id, type: 'output', data }));
      }
    });
    term.onExit(({ exitCode }) => {
      session.alive = false;
      if (ws.readyState === 1) {
        ws.send(JSON.stringify({ channel: 'pty', id, type: 'exit', exitCode }));
      }
      this.sessions.delete(id);
    });

    this.sessions.set(id, session);
    ws.send(
      JSON.stringify({ channel: 'pty', id, type: 'spawned', shell, cols, rows, cwd })
    );
    return id;
  }

  input(id, data) {
    const session = this.sessions.get(id);
    if (session && session.alive && typeof data === 'string') {
      session.term.write(data);
      return true;
    }
    return false;
  }

  resize(id, cols, rows) {
    const session = this.sessions.get(id);
    if (!session || !session.alive) return false;
    const nextCols = Math.max(20, Math.min(400, Number(cols) || 80));
    const nextRows = Math.max(5, Math.min(200, Number(rows) || 24));
    session.term.resize(nextCols, nextRows);
    return true;
  }

  destroy(id) {
    const session = this.sessions.get(id);
    if (!session) return false;
    session.alive = false;
    try {
      session.term.kill();
    } catch (_error) {
      /* already gone */
    }
    this.sessions.delete(id);
    return true;
  }

  destroyBySocket(ws) {
    for (const [id, session] of [...this.sessions]) {
      if (session.ws === ws) this.destroy(id);
    }
  }

  destroyAll() {
    for (const id of [...this.sessions.keys()]) this.destroy(id);
  }
}

module.exports = PtyMultiplexer;
