'use strict';
// Client for the Python daemon's newline-delimited JSON event stream on a UDS.
// Events are emitted as parsed objects; the raw frame is emitted alongside them
// so the WS layer can forward with a single JSON serialization step.

const net = require('net');
const { EventEmitter } = require('events');

class SystemBridge extends EventEmitter {
  constructor(socketPath) {
    super();
    this.socketPath = socketPath;
    this.socket = null;
    this.buffer = '';
    this.ready = false;
    this.delay = 250;
    this.timer = null;
  }

  connect() {
    if (this.socket || this.timer) return;
    const socket = net.createConnection(this.socketPath);
    this.socket = socket;
    socket.setNoDelay(true);

    socket.on('connect', () => {
      this.ready = true;
      this.delay = 250;
      this.emit('ready');
    });

    socket.on('data', (chunk) => {
      this.buffer += chunk.toString('utf8');
      let newline;
      while ((newline = this.buffer.indexOf('\n')) !== -1) {
        const frame = this.buffer.slice(0, newline);
        this.buffer = this.buffer.slice(newline + 1);
        if (!frame) continue;
        this.emit('frame', frame);
        try {
          this.emit('event', JSON.parse(frame));
        } catch (error) {
          this.emit('error', error);
        }
      }
      // Guard against unbounded growth if a frame never terminates.
      if (this.buffer.length > 4 * 1024 * 1024) this.buffer = '';
    });

    socket.on('error', (error) => this.emit('error', error));

    socket.on('close', () => {
      this.ready = false;
      this.socket = null;
      this.buffer = '';
      this.timer = setTimeout(() => {
        this.timer = null;
        this.connect();
      }, this.delay);
      this.delay = Math.min(this.delay * 2, 5000);
    });
  }

  close() {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    if (this.socket) this.socket.destroy();
    this.socket = null;
    this.ready = false;
  }
}

module.exports = { SystemBridge };
