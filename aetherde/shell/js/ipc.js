// WebSocket IPC client. One connection carries system events, PTY streams and
// correlated filesystem requests; REST calls go through the same-origin gateway.

export class IPC {
  constructor() {
    this.listeners = new Map();
    this.pending = new Map();
    this.seq = 0;
    this.delay = 250;
    this.timer = null;
    this.ws = null;
    this.connect();
  }

  on(topic, handler) {
    if (!this.listeners.has(topic)) this.listeners.set(topic, new Set());
    this.listeners.get(topic).add(handler);
    return () => this.listeners.get(topic)?.delete(handler);
  }

  emit(topic, payload) {
    for (const handler of this.listeners.get(topic) || []) {
      try {
        handler(payload);
      } catch (error) {
        console.error(`[ipc] listener for ${topic} failed`, error);
      }
    }
  }

  send(channel, payload = {}) {
    if (this.ws && this.ws.readyState === 1) {
      this.ws.send(JSON.stringify({ channel, ...payload }));
    }
  }

  request(channel, payload = {}, timeout = 10000) {
    const id = ++this.seq;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error('request timed out'));
      }, timeout);
      this.pending.set(id, { resolve, reject, timer });
      this.send(channel, { ...payload, id });
    });
  }

  async api(path, options = {}) {
    const response = await fetch(path, {
      ...options,
      headers: { 'content-type': 'application/json', ...(options.headers || {}) },
    });
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    return response.json();
  }

  async post(path, body = {}) {
    return this.api(path, { method: 'POST', body: JSON.stringify(body) });
  }

  connect() {
    const scheme = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const ws = new WebSocket(`${scheme}//${location.host}/ws`);
    this.ws = ws;

    ws.addEventListener('open', () => {
      this.delay = 250;
      this.emit('connected', {});
    });

    ws.addEventListener('message', (event) => {
      let message;
      try {
        message = JSON.parse(event.data);
      } catch (_error) {
        return;
      }
      if (message.channel === 'sys') {
        if (message.type === 'hello' || message.type === 'pong') {
          this.emit('hello', message);
          return;
        }
        if (message.topic) this.emit(message.topic, message.data);
      } else if (message.channel === 'fs') {
        const entry = this.pending.get(message.id);
        if (entry) {
          clearTimeout(entry.timer);
          this.pending.delete(message.id);
          if (message.ok) entry.resolve(message.result);
          else entry.reject(new Error(message.error || 'filesystem request failed'));
        }
      } else if (message.channel === 'pty') {
        this.emit(`pty:${message.type}`, message);
      }
    });

    ws.addEventListener('close', () => {
      this.emit('disconnected', {});
      this.schedule();
    });
    ws.addEventListener('error', () => ws.close());
  }

  schedule() {
    if (this.timer) return;
    this.timer = setTimeout(() => {
      this.timer = null;
      this.connect();
    }, this.delay);
    this.delay = Math.min(this.delay * 2, 5000);
  }
}

export const ipc = new IPC();
