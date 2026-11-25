'use strict';
// AetherDE realtime gateway: Fastify + ws bridge from the Python UDS to the
// browser, a node-pty multiplexer, and a sandboxed filesystem API.

const http = require('http');
const fs = require('fs');
const path = require('path');
const fastify = require('fastify');
const websocket = require('@fastify/websocket');
const fastifyStatic = require('@fastify/static');

const { SystemBridge } = require('./ipc');
const PtyMultiplexer = require('./pty');
const fsapi = require('./fsapi');

function parseArgs(argv) {
  const options = {
    socket: '/tmp/aether-sys.sock',
    port: 0,
    portFile: null,
    static: path.join(__dirname, '..', 'shell'),
  };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--socket') options.socket = argv[++index];
    else if (argument === '--port') options.port = Number(argv[++index]);
    else if (argument === '--port-file') options.portFile = argv[++index];
    else if (argument === '--static') options.static = argv[++index];
  }
  return options;
}

function proxyToDaemon(options, request, reply) {
  reply.hijack();
  const body =
    request.body === undefined
      ? ''
      : typeof request.body === 'string'
        ? request.body
        : JSON.stringify(request.body);

  const headers = { 'content-type': 'application/json' };
  if (body) headers['content-length'] = Buffer.byteLength(body);

  const upstream = http.request({
    socketPath: options.socket,
    method: request.method,
    path: request.url,
    headers,
  });

  upstream.on('response', (response) => {
    const responseHeaders = {};
    for (const [key, value] of Object.entries(response.headers)) {
      if (['connection', 'transfer-encoding', 'keep-alive'].includes(key)) continue;
      responseHeaders[key] = value;
    }
    reply.raw.writeHead(response.statusCode || 502, responseHeaders);
    response.pipe(reply.raw);
  });

  upstream.on('error', (error) => {
    if (!reply.raw.headersSent) {
      reply.raw.writeHead(502, { 'content-type': 'application/json' });
    }
    reply.raw.end(JSON.stringify({ error: error.message }));
  });

  if (body) upstream.write(body);
  upstream.end();
}

async function handleFs(socket, message) {
  const { id, op } = message;
  const args = Array.isArray(message.args) ? message.args : [];
  try {
    let result;
    switch (op) {
      case 'list': result = await fsapi.list(args[0]); break;
      case 'read': result = await fsapi.read(args[0]); break;
      case 'write': result = await fsapi.write(args[0], args[1]); break;
      case 'mkdir': result = await fsapi.mkdir(args[0]); break;
      case 'rename': result = await fsapi.rename(args[0], args[1]); break;
      case 'copy': result = await fsapi.copy(args[0], args[1]); break;
      case 'remove': result = await fsapi.remove(args[0]); break;
      case 'stat': result = await fsapi.stat(args[0]); break;
      case 'thumbnail': result = await fsapi.thumbnail(args[0], args[1]); break;
      default: throw new Error(`unknown filesystem operation: ${op}`);
    }
    if (socket.readyState === 1) {
      socket.send(JSON.stringify({ channel: 'fs', id, ok: true, result }));
    }
  } catch (error) {
    if (socket.readyState === 1) {
      socket.send(
        JSON.stringify({
          channel: 'fs',
          id,
          ok: false,
          error: error.message,
          statusCode: error.statusCode || 500,
        })
      );
    }
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const bridge = new SystemBridge(options.socket);
  const multiplexer = new PtyMultiplexer();
  const app = fastify({ logger: false, bodyLimit: 16 * 1024 * 1024 });

  await app.register(websocket, { options: { maxPayload: 32 * 1024 * 1024 } });
  await app.register(fastifyStatic, { root: options.static, prefix: '/' });
  await app.register(fastifyStatic, {
    root: path.join(__dirname, 'node_modules', '@xterm', 'xterm', 'lib'),
    prefix: '/vendor/xterm/',
    decorateReply: false,
  });
  await app.register(fastifyStatic, {
    root: path.join(__dirname, 'node_modules', '@xterm', 'addon-fit', 'lib'),
    prefix: '/vendor/xterm-fit/',
    decorateReply: false,
  });

  app.all('/api/*', (request, reply) => proxyToDaemon(options, request, reply));

  app.get('/ws', { websocket: true }, (socket) => {
    socket.send(JSON.stringify({ channel: 'sys', type: 'hello', ts: Date.now() }));

    const forward = (event) => {
      if (socket.readyState === 1) {
        socket.send(JSON.stringify({ channel: 'sys', ...event }));
      }
    };
    bridge.on('event', forward);

    socket.on('message', (raw) => {
      let message;
      try {
        message = JSON.parse(raw.toString());
      } catch (_error) {
        return;
      }
      if (message.channel === 'pty') {
        if (message.type === 'spawn') multiplexer.create(socket, message);
        else if (message.type === 'input') multiplexer.input(message.id, message.data);
        else if (message.type === 'resize') {
          multiplexer.resize(message.id, message.cols, message.rows);
        } else if (message.type === 'kill') multiplexer.destroy(message.id);
      } else if (message.channel === 'fs') {
        handleFs(socket, message);
      } else if (message.channel === 'sys' && message.type === 'ping') {
        socket.send(JSON.stringify({ channel: 'sys', type: 'pong', id: message.id }));
      }
    });

    socket.on('close', () => {
      bridge.off('event', forward);
      multiplexer.destroyBySocket(socket);
    });
    socket.on('error', () => {});
  });

  bridge.on('error', (error) => {
    console.error('[aether-gateway] bridge error:', error.message);
  });
  bridge.connect();

  const announced = await app.listen({ host: '127.0.0.1', port: options.port });
  const bound = app.server.address();
  const port = typeof bound === 'object' && bound ? bound.port : options.port;
  if (options.portFile) fs.writeFileSync(options.portFile, String(port), 'utf8');
  console.log(`[aether-gateway] ${announced} -> ${options.socket}`);

  let shuttingDown = false;
  async function shutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`[aether-gateway] ${signal} received, shutting down`);
    multiplexer.destroyAll();
    bridge.close();
    try {
      await app.close();
    } catch (_error) {
      /* already closed */
    }
    if (options.portFile) {
      try {
        fs.unlinkSync(options.portFile);
      } catch (_error) {
        /* already removed */
      }
    }
    process.exit(0);
  }

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGHUP', () => shutdown('SIGHUP'));
}

main().catch((error) => {
  console.error('[aether-gateway] fatal:', error);
  process.exit(1);
});
