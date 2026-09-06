// Host adapter for HarmonyOS primitives. Application/protocol/service logic is
// loaded unchanged from .ets. This proves protocol behavior, not device ABI/UI.
const fs = require('node:fs');
const fsp = fs.promises;
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const net = require('node:net');
const tls = require('node:tls');
const dgram = require('node:dgram');
const ts = require(process.env.TYPESCRIPT_PATH || 'E:/Huawei/DevEco_Studio/tools/hvigor/hvigor/node_modules/typescript');
const root = path.join(__dirname, '../AloeSend/entry/src/main/ets');
const handles = new Map(); let nextFd = 1;
const caches = new Map();
const modes = { READ_ONLY: 0, READ_WRITE: 2, CREATE: 64, TRUNC: 512 };
const nativeFs = {
  OpenMode: modes,
  async open(file, mode) {
    const handle = await fsp.open(file.replace(/^file:\/\//, ''), mode & modes.CREATE ? 'w+' : mode & modes.READ_WRITE ? 'r+' : 'r');
    const fd = nextFd++; handles.set(fd, handle); return { fd };
  },
  async close(file) { const fd = typeof file === 'number' ? file : file.fd; const h = handles.get(fd); handles.delete(fd); if (h) await h.close(); },
  async stat(file) { return typeof file === 'number' ? handles.get(file).stat() : fsp.stat(file); },
  async read(fd, data) { return (await handles.get(fd).read(new Uint8Array(data), 0, data.byteLength, null)).bytesRead; },
  async write(fd, data) { const b = typeof data === 'string' ? Buffer.from(data) : Buffer.from(data); return (await handles.get(fd).write(b, 0, b.length, null)).bytesWritten; },
  readText: file => fsp.readFile(file, 'utf8'),
  async copyFile(source, destination) {
    const buffer = Buffer.alloc(65536); let position = 0;
    while (true) {
      const { bytesRead } = await handles.get(source).read(buffer, 0, buffer.length, position);
      if (!bytesRead) break;
      await handles.get(destination).write(buffer, 0, bytesRead, position); position += bytesRead;
    }
  },
  mkdir: (file, recursion) => fsp.mkdir(file, { recursive: !!recursion }),
  rename: (a, b) => fsp.rename(a, b),
  unlink: file => fsp.unlink(file),
  listFile: file => fsp.readdir(file),
};

class SocketAdapter {
  constructor(isTls, socket) { this.isTls = isTls; this.socket = socket; this.listeners = []; if (socket) this.attach(); }
  async bind(address) { this.bindAddress = address; }
  on(name, callback) {
    if (this.isTls && !this.socket && !this.bindAddress) throw new Error('HarmonyOS TLSSocket.on requires successful bind first');
    this.listeners.push([name, callback]); if (this.socket) this.install(name, callback);
  }
  install(name, cb) {
    if (name === 'message') this.socket.on('data', data => cb({ message: Uint8Array.from(data).buffer, remoteInfo: { address: this.socket.remoteAddress?.replace(/^::ffff:/, ''), port: this.socket.remotePort } }));
    else this.socket.on(name, cb);
  }
  attach() { for (const [name, cb] of this.listeners) this.install(name, cb); }
  async connect(options) {
    if (!this.bindAddress) throw new Error('Explicit client bind missing');
    const settings = { host: options.address.address, port: options.address.port, localAddress: this.bindAddress.address, localPort: this.bindAddress.port };
    this.socket = this.isTls ? tls.connect({ ...settings, rejectUnauthorized: false }) : net.connect(settings);
    this.attach();
    await new Promise((resolve, reject) => { this.socket.once(this.isTls ? 'secureConnect' : 'connect', resolve); this.socket.once('error', reject); });
  }
  async send(data) {
    const bytes = this.isTls ? data : data.data;
    await new Promise((resolve, reject) => this.socket.write(Buffer.from(bytes), error => error ? reject(error) : resolve()));
  }
  async getRemoteCertificate() { return { data: new Uint8Array(this.socket.getPeerCertificate().raw), encodingFormat: 0 }; }
  async close() { if (this.socket && !this.socket.destroyed) this.socket.end(); }
}

class ServerAdapter {
  constructor(isTls) { this.isTls = isTls; this.callbacks = {}; this.clients = new Set(); }
  on(name, cb) {
    // Both HarmonyOS server APIs require successful listen before subscribing.
    // Node normally permits the reverse order, which concealed a device bug.
    if (!this.server?.listening) throw new Error('HarmonyOS server.on requires listen to complete first');
    this.callbacks[name] = cb;
  }
  async listen(options) {
    const handle = client => {
      this.clients.add(client); client.on('close', () => this.clients.delete(client));
      this.callbacks.connect?.(new SocketAdapter(this.isTls, client));
    };
    this.server = this.isTls ? tls.createServer({ key: options.secureOptions.key, cert: options.secureOptions.cert }, handle) : net.createServer(handle);
    this.server.on('error', error => this.callbacks.error?.(error));
    this.server.on('tlsClientError', () => {});
    const address = this.isTls ? options.address : options;
    await new Promise((resolve, reject) => { this.server.once('error', reject); this.server.listen(address.port, address.address, resolve); });
  }
  async close() { for (const client of this.clients) client.destroy(); if (this.server?.listening) await new Promise(resolve => this.server.close(resolve)); }
}

class MulticastAdapter {
  constructor() { this.socket = dgram.createSocket({ type: 'udp4', reuseAddr: true }); this.socket.on('error', () => {}); }
  on(name, cb) {
    if (name === 'message') this.socket.on('message', (data, remote) => cb({ message: Uint8Array.from(data).buffer, remoteInfo: remote }));
    else this.socket.on(name, cb);
  }
  async bind(address) { await new Promise((resolve, reject) => { this.socket.once('error', reject); this.socket.bind(address.port, address.address, resolve); }); }
  async setExtraOptions() {}
  async addMembership(address) { this.socket.addMembership(address.address); }
  async setMulticastTTL(ttl) { this.socket.setMulticastTTL(ttl); }
  async send(options) { await new Promise((resolve, reject) => this.socket.send(options.data, options.address.port, options.address.address, e => e ? reject(e) : resolve())); }
  async close() { try { this.socket.close(); } catch (_) {} }
}

const cryptoFramework = {
  createAsyKeyGenerator() { return { async generateKeyPair() {
    const pair = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
    return { pubKey: { getEncoded: () => ({ data: new Uint8Array(pair.publicKey.export({ format: 'der', type: 'spki' })) }) },
      priKey: { native: pair.privateKey, getEncoded: () => ({ data: new Uint8Array(pair.privateKey.export({ format: 'der', type: 'pkcs8' })) }) } };
  } }; },
  createRandom: () => ({ generateRandom: async count => ({ data: new Uint8Array(crypto.randomBytes(count)) }) }),
  createSign: () => ({ async init(key) { this.key = key.native; }, async sign(blob) { return { data: new Uint8Array(crypto.sign('sha256', blob.data, this.key)) }; } }),
  createMd: () => { const hash = crypto.createHash('sha256'); return { update: async blob => { hash.update(blob.data); }, digest: async () => ({ data: new Uint8Array(hash.digest()) }) }; },
};
const mocks = {
  '@kit.NetworkKit': { socket: {
    constructTCPSocketInstance: () => new SocketAdapter(false), constructTLSSocketInstance: () => new SocketAdapter(true),
    constructTCPSocketServerInstance: () => new ServerAdapter(false), constructTLSSocketServerInstance: () => new ServerAdapter(true),
    constructMulticastSocketInstance: () => new MulticastAdapter(),
  }, connection: { getAllNets: async () => [], getConnectionProperties: async () => ({ linkAddresses: [] }) } },
  '@kit.ArkTS': { util: { generateRandomUUID: () => crypto.randomUUID(),
    TextEncoder: class { encodeInto(text) { return new Uint8Array(Buffer.from(text)); } },
    TextDecoder: class { decodeToString(data) { return Buffer.from(data).toString('utf8'); } },
    Base64Helper: class { encodeToStringSync(data) { return Buffer.from(data).toString('base64'); } decodeSync(data) { return new Uint8Array(Buffer.from(data, 'base64')); } },
  } },
  '@kit.CryptoArchitectureKit': { cryptoFramework },
  '@kit.CoreFileKit': { fileIo: nativeFs, fileUri: { FileUri: class { constructor(uri) { this.name = path.basename(uri); } }, getUriFromPath: file => file }, picker: {},
    fileShare: { OperationMode: { READ_MODE: 1, WRITE_MODE: 2 }, activatePermission: async () => {}, persistPermission: async () => {} } },
  '@kit.BasicServicesKit': { pasteboard: {} },
  '@kit.ShareKit': { systemShare: {} },
  '@kit.MediaLibraryKit': { photoAccessHelper: {} },
  '@kit.LocalizationKit': { i18n: { System: { getSystemLanguage: () => 'zh-Hans' } } },
  '@kit.BackgroundTasksKit': { backgroundTaskManager: { BackgroundMode: { DATA_TRANSFER: 1 }, startBackgroundRunning: async () => {}, stopBackgroundRunning: async () => {} } },
  '@kit.AbilityKit': { ConfigurationConstant: { ColorMode: { COLOR_MODE_DARK: 0, COLOR_MODE_LIGHT: 1, COLOR_MODE_NOT_SET: -1 } } },
  '@kit.ArkData': { preferences: { getPreferences: async context => {
    const values = new Map(); return { get: async (key, fallback) => values.has(key) ? values.get(key) : fallback, put: async (key, value) => values.set(key, value), flush: async () => {} };
  } } },
};
function load(relative) {
  const fullPath = path.isAbsolute(relative) ? relative : path.join(root, relative);
  const file = fullPath.endsWith('.ets') ? fullPath : fullPath + '.ets';
  if (caches.has(file)) return caches.get(file);
  const output = ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS, experimentalDecorators: true } }).outputText;
  const exports = {}; caches.set(file, exports);
  const localRequire = name => name.startsWith('.') ? load(path.resolve(path.dirname(file), name)) : mocks[name] || require(name);
  vm.runInNewContext(output, { exports, require: localRequire, Observed: value => value, Uint8Array, ArrayBuffer, Date, Error, Promise, Map, Set, Number, Object, JSON, String, Math, RegExp, parseInt, encodeURIComponent, decodeURIComponent, setTimeout, clearTimeout, setInterval, clearInterval, console }, { filename: file });
  return exports;
}
module.exports = { load, handles, mocks };
