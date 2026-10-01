// reference-server.mjs — 在本产品进程中运行可信的 P(DOOM) 引擎，不修改参考仓库。
import { createServer, normalizePath } from 'vite';
import { createServer as createNetServer } from 'node:net';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';
import { renderShotsWithTransitions } from './transitions.mjs';

const productRoot = fileURLToPath(new URL('../..', import.meta.url));

async function reservePort() {
  const probe = createNetServer();
  await new Promise((resolveProbe, reject) => {
    probe.once('error', reject);
    probe.listen(0, '127.0.0.1', resolveProbe);
  });
  const address = probe.address();
  await new Promise((resolveClose, reject) => probe.close((error) => error ? reject(error) : resolveClose()));
  if (!address || typeof address === 'string') throw new Error('无法分配参考引擎端口');
  return address.port;
}

export async function startReferenceServer({ root = resolve(productRoot, '../pdoom-video'), port = 0, shots, transitions = [], fps = 30 } = {}) {
  const renderShots = shots ? renderShotsWithTransitions(shots, transitions, fps) : null;
  const dependencies = transitions.filter((transition) => transition.mode !== 'cut').map(({ fromShotId, toShotId }) => [fromShotId, toShotId]);
  const app = join(root, 'app');
  const listenPort = port === 0 ? await reservePort() : port;
  const server = await createServer({
    configFile: false,
    root: app,
    publicDir: 'public',
    cacheDir: resolve(productRoot, '.cache/reference-vite'),
    logLevel: 'error',
    plugins: [{
      name: 'videograph-reference-assets',
      resolveId(id) { if (id === 'virtual:videograph-transitions') return '\0videograph-transitions'; },
      load(id) { if (id === '\0videograph-transitions') return readFileSync(new URL('./transition-runtime.mjs', import.meta.url), 'utf8'); },
      transformIndexHtml() {
        return [{ tag: 'link', attrs: { rel: 'icon', type: 'image/svg+xml', href: `/@fs/${normalizePath(join(productRoot, 'public/favicon.svg'))}` }, injectTo: 'head' }];
      },
      configureServer(vite) {
        vite.middlewares.use((req, _res, next) => {
          if (['/audio/', '/data/'].some((prefix) => req.url?.startsWith(prefix))) {
            req.url = `/@fs/${encodeURI(normalizePath(root))}${req.url}`;
          }
          next();
        });
      },
      transform(code, id) {
        if (shots && normalizePath(id).endsWith('/src/main.ts')) {
          return code.replace('await engine.init(onlySet ? (e) => onlySet.has(e.id) : undefined);', `if (onlySet) for (const [from, to] of ${JSON.stringify(dependencies)}) if (onlySet.has(to)) onlySet.add(from);\n await engine.init(onlySet ? (e) => onlySet.has(e.id) : undefined);`)
            .replace('TIMELINE = engine.timeline;', `TIMELINE = !EXPORT && ONLY ? engine.timeline.filter(e => ONLY.split(",").includes(e.id)).map(e => ({...e, ...${JSON.stringify(shots.map(({ id, start, end }) => ({ id, start: Math.round(start * fps) / fps, end: Math.round(end * fps) / fps })))}.find(s => s.id === e.id)})) : engine.timeline;`)
            .replace('scrub.max = String(engine.duration);', 'scrub.min = String(params.get("rangeStart") ?? TIMELINE[0]?.start ?? 0); scrub.max = String(params.get("rangeEnd") ?? TIMELINE[TIMELINE.length - 1]?.end ?? engine.duration);')
            .replace('let loop: [number, number] | null = null;', 'let loop: [number, number] | null = ONLY && TIMELINE.length ? [Number(scrub.min), Number(scrub.max)] : null;');
        }
        if (!renderShots || !normalizePath(id).endsWith('/src/timeline.ts')) return;
        const imports = `import { wrapTransitionScene } from 'virtual:videograph-transitions';\n` + renderShots.map((shot, index) => `const vgLoad${index} = async () => { const mod = await import('/src/scenes/${shot.module}.ts'); return {default: wrapTransitionScene(mod.default, ${JSON.stringify({ start: shot.start, end: shot.end, logicalStart: shot.logicalStart, logicalEnd: shot.logicalEnd, incomingTransition: shot.incomingTransition })}, ${fps})}; };`).join('\n');
        return `${code.replace('export function makeTimeline(', 'function referenceTimeline(')}\n${imports}\nexport function makeTimeline(ly, au) {\n const original = referenceTimeline(ly, au);\n return [${renderShots.map((shot, index) => `({...original.find(e=>e.id===${JSON.stringify(shot.id)}), ...${JSON.stringify({ id: shot.id, start: shot.start, end: shot.end, params: shot.params ?? {}, post: shot.post ?? {} })}, load: vgLoad${index}})`).join(',')}];\n}`;
      },
    }],
    resolve: { alias: {
      three: resolve(productRoot, 'node_modules/three/build/three.module.js'),
      'opentype.js': resolve(productRoot, 'node_modules/opentype.js/dist/opentype.mjs'),
    } },
    optimizeDeps: { noDiscovery: true, include: [] },
    server: { host: '127.0.0.1', port: listenPort, strictPort: true, hmr: false,
      headers: { 'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; media-src 'self' blob:; connect-src 'self' ws://127.0.0.1:*; object-src 'none'; base-uri 'none'" },
      fs: { allow: [root, join(productRoot, 'node_modules'), join(productRoot, 'public/favicon.svg')] } },
  });
  await server.listen();
  const address = server.httpServer.address();
  return { url: `http://127.0.0.1:${address.port}`, close: () => server.close() };
}
