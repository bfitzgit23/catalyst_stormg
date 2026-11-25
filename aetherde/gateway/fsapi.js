'use strict';
// Sandboxed local filesystem API for the web file-manager widget.

const fsp = require('fs/promises');
const { constants } = require('fs');
const path = require('path');
const os = require('os');
const { createHash } = require('crypto');
const { execFile } = require('child_process');
const { promisify } = require('util');

const execFileAsync = promisify(execFile);
const ROOTS = [os.homedir(), os.tmpdir()];
const IMAGE_EXTENSIONS = new Set([
  '.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg', '.tif', '.tiff', '.avif',
]);

function resolveSafe(input) {
  const target = path.resolve(input || os.homedir());
  const permitted = ROOTS.some(
    (root) => target === root || target.startsWith(root + path.sep)
  );
  if (!permitted) {
    const error = new Error('path is outside the allowed roots');
    error.statusCode = 403;
    throw error;
  }
  return target;
}

async function list(target) {
  const dir = resolveSafe(target);
  const entries = await fsp.readdir(dir, { withFileTypes: true });
  const items = await Promise.all(
    entries.map(async (entry) => {
      const full = path.join(dir, entry.name);
      let info = null;
      try {
        info = await fsp.stat(full);
      } catch (_error) {
        info = null;
      }
      return {
        name: entry.name,
        path: full,
        type: entry.isDirectory() ? 'dir' : entry.isSymbolicLink() ? 'link' : 'file',
        size: info ? info.size : 0,
        mtime: info ? info.mtimeMs : 0,
        ext: path.extname(entry.name).toLowerCase(),
      };
    })
  );
  items.sort(
    (a, b) =>
      (a.type === 'dir' ? -1 : 1) - (b.type === 'dir' ? -1 : 1) ||
      a.name.localeCompare(b.name)
  );
  return { path: dir, parent: path.dirname(dir), items };
}

async function read(target) {
  return { path: resolveSafe(target), content: await fsp.readFile(resolveSafe(target), 'utf8') };
}

async function write(target, content) {
  const file = resolveSafe(target);
  await fsp.mkdir(path.dirname(file), { recursive: true });
  await fsp.writeFile(file, String(content ?? ''), 'utf8');
  return { path: file, ok: true };
}

async function mkdir(target) {
  const dir = resolveSafe(target);
  await fsp.mkdir(dir, { recursive: true });
  return { path: dir, ok: true };
}

async function rename(from, to) {
  const source = resolveSafe(from);
  const destination = resolveSafe(to);
  await fsp.mkdir(path.dirname(destination), { recursive: true });
  await fsp.rename(source, destination);
  return { from: source, to: destination, ok: true };
}

async function copy(from, to) {
  const source = resolveSafe(from);
  const destination = resolveSafe(to);
  await fsp.mkdir(path.dirname(destination), { recursive: true });
  await fsp.copyFile(source, destination);
  return { from: source, to: destination, ok: true };
}

async function remove(target) {
  const file = resolveSafe(target);
  await fsp.rm(file, { recursive: true, force: true });
  return { path: file, ok: true };
}

async function stat(target) {
  const file = resolveSafe(target);
  const info = await fsp.stat(file);
  return {
    path: file,
    size: info.size,
    mtime: info.mtimeMs,
    isDirectory: info.isDirectory(),
    isFile: info.isFile(),
  };
}

async function findBinary(name) {
  for (const directory of (process.env.PATH || '').split(path.delimiter)) {
    if (!directory) continue;
    const candidate = path.join(directory, name);
    try {
      await fsp.access(candidate, constants.X_OK);
      return candidate;
    } catch (_error) {
      continue;
    }
  }
  return null;
}

async function thumbnail(target, size = 128) {
  const source = resolveSafe(target);
  if (!IMAGE_EXTENSIONS.has(path.extname(source).toLowerCase())) {
    return { path: source, generated: false, reason: 'unsupported type' };
  }
  const info = await fsp.stat(source);
  const dimension = Math.max(16, Math.min(512, Number(size) || 128));
  const hash = createHash('sha1')
    .update(`${source}:${info.mtimeMs}:${dimension}`)
    .digest('hex');
  const cacheDir = path.join(os.homedir(), '.cache', 'aether-de', 'thumbs');
  const output = path.join(cacheDir, `${hash}.png`);
  await fsp.mkdir(cacheDir, { recursive: true });
  try {
    await fsp.access(output, constants.R_OK);
    return { path: output, generated: true };
  } catch (_error) {
    /* generate below */
  }
  const binary = (await findBinary('magick')) || (await findBinary('convert'));
  if (!binary) return { path: source, generated: false, reason: 'no image backend' };
  await execFileAsync(binary, [
    source,
    '-auto-orient',
    '-thumbnail',
    `${dimension}x${dimension}>`,
    '-strip',
    output,
  ]);
  return { path: output, generated: true };
}

module.exports = {
  resolveSafe,
  list,
  read,
  write,
  mkdir,
  rename,
  copy,
  remove,
  stat,
  thumbnail,
};
